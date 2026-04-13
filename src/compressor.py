"""Compresion lossless de tablas HTML pixel-art."""

import re


# ---------------------------------------------------------------------------
# Expresiones regulares
# ---------------------------------------------------------------------------

PIXEL_ART_TR_PATTERN = re.compile(
    r"(<tr(?:\s[^>]*)?>)"
    r"\s*"
    r"((?:<td\s+[^>]*></td>\s*)+)"
    r"(</tr>)",
    re.IGNORECASE,
)

PIXEL_ART_SEQUENCE_PATTERN = re.compile(
    r"(?:<tr(?:\s[^>]*)?>\s*(?:<td\s+[^>]*></td>\s*)+</tr>\s*)+",
    re.IGNORECASE,
)

PIXEL_ART_TR_INSIDE_SEQUENCE = re.compile(
    r"<tr(?:\s[^>]*)?>\s*((?:<td\s+[^>]*></td>\s*)+)</tr>",
    re.IGNORECASE,
)

TD_PATTERN = re.compile(r"<td\s+([^>]*)></td>", re.IGNORECASE)
ATTR_PATTERN = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
ALL_TD_TAG_PATTERN = re.compile(r"<td\b", re.IGNORECASE)

ALLOWED_CELL_ATTRS = {"width", "height", "bgcolor"}


# ---------------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------------

def parse_attrs(attr_str):
    return {
        m.group(1).lower(): m.group(2)
        for m in ATTR_PATTERN.finditer(attr_str)
    }


def run_length_encode(items):
    runs = []
    for item in items:
        if runs and runs[-1][0] == item:
            runs[-1] = (runs[-1][0], runs[-1][1] + 1)
        else:
            runs.append((item, 1))
    return runs


def parse_row_cells(tr_content):
    cells = []
    for td_match in TD_PATTERN.finditer(tr_content):
        attrs = parse_attrs(td_match.group(1))
        if set(attrs.keys()) - ALLOWED_CELL_ATTRS:
            return None
        if "bgcolor" not in attrs:
            return None
        cells.append(attrs)
    return cells if cells else None


def format_bytes(n):
    if n < 1024:
        return f"{n:,} B"
    if n < 1024 * 1024:
        return f"{n / 1024:,.1f} KB"
    return f"{n / (1024 * 1024):,.2f} MB"


# ---------------------------------------------------------------------------
# Modo agresivo
# ---------------------------------------------------------------------------

def _compress_tr_aggressive(match):
    tr_open = match.group(1)
    tr_content = match.group(2)
    tr_close = match.group(3)

    cells = parse_row_cells(tr_content)
    if cells is None:
        return match.group(0)

    widths = {c.get("width", "") for c in cells}
    heights = {c.get("height", "") for c in cells}

    if len(widths) != 1 or len(heights) != 1:
        return match.group(0)

    width_str = cells[0].get("width", "")
    height_str = cells[0].get("height", "")

    if not width_str.isdigit() or int(width_str) < 1:
        return match.group(0)

    width = int(width_str)
    runs = run_length_encode([c["bgcolor"] for c in cells])

    compressed_cells = []
    for color, count in runs:
        total_width = width * count
        attrs_parts = [f'width="{total_width}"']
        if count > 1:
            attrs_parts.append(f'colspan="{count}"')
        attrs_parts.append(f'bgcolor="{color}"')
        compressed_cells.append(f"<td {' '.join(attrs_parts)}></td>")

    if height_str and height_str.isdigit():
        tr_attrs_match = re.match(r"<tr(\s[^>]*)?>", tr_open, re.IGNORECASE)
        existing_attrs = (tr_attrs_match.group(1) or "").rstrip()
        if "height" not in existing_attrs.lower():
            new_tr_open = f'<tr{existing_attrs} height="{height_str}">'
        else:
            new_tr_open = tr_open
    else:
        new_tr_open = tr_open

    return new_tr_open + "".join(compressed_cells) + tr_close


# ---------------------------------------------------------------------------
# Modo safari-safe
# ---------------------------------------------------------------------------

def _compress_sequence_safari_safe(match):
    sequence = match.group(0)

    rows_data = []
    for tr_match in PIXEL_ART_TR_INSIDE_SEQUENCE.finditer(sequence):
        cells = parse_row_cells(tr_match.group(1))
        if cells is None:
            return match.group(0)
        rows_data.append(cells)

    if not rows_data:
        return match.group(0)

    all_widths = set()
    all_heights = set()
    for cells in rows_data:
        for c in cells:
            all_widths.add(c.get("width", ""))
            all_heights.add(c.get("height", ""))

    if len(all_widths) != 1 or len(all_heights) != 1:
        return match.group(0)

    width_str = next(iter(all_widths))
    height_str = next(iter(all_heights))

    if not width_str.isdigit() or not height_str.isdigit():
        return match.group(0)

    cell_width = int(width_str)
    cell_height = int(height_str)

    if cell_width < 1 or cell_height < 1:
        return match.group(0)

    output_rows = []
    absorbed = [False] * len(rows_data)

    def cells_bgcolors(cells):
        return tuple(c["bgcolor"] for c in cells)

    for i in range(len(rows_data)):
        if absorbed[i]:
            output_rows.append("<tr></tr>")
            continue

        current_colors = cells_bgcolors(rows_data[i])

        identical_count = 1
        for j in range(i + 1, len(rows_data)):
            if cells_bgcolors(rows_data[j]) == current_colors:
                identical_count += 1
                absorbed[j] = True
            else:
                break

        if identical_count >= 2:
            runs = run_length_encode(list(current_colors))
            total_row_height = identical_count * cell_height
            cells_html = []
            for color, count in runs:
                total_width = count * cell_width
                attrs_parts = [
                    f'width="{total_width}"',
                    f'height="{total_row_height}"',
                ]
                if count > 1:
                    attrs_parts.append(f'colspan="{count}"')
                attrs_parts.append(f'rowspan="{identical_count}"')
                attrs_parts.append(f'bgcolor="{color}"')
                cells_html.append(f"<td {' '.join(attrs_parts)}></td>")
            output_rows.append("<tr>" + "".join(cells_html) + "</tr>")
        else:
            cells_html = []
            for color in current_colors:
                cells_html.append(
                    f'<td width="{cell_width}" height="{cell_height}" '
                    f'bgcolor="{color}"></td>'
                )
            output_rows.append("<tr>" + "".join(cells_html) + "</tr>")

    return "\n".join(output_rows) + "\n"


# ---------------------------------------------------------------------------
# API publica
# ---------------------------------------------------------------------------

def compress_html(html_content, aggressive=False):
    """Comprime tablas HTML pixel-art sin perdida visual.

    Args:
        html_content: HTML a comprimir.
        aggressive: True para modo agresivo (mas compresion, bug Safari).
                   False para modo safari-safe (compatible con todo).

    Returns:
        Tupla (html_comprimido, stats_dict).
    """
    td_before = len(ALL_TD_TAG_PATTERN.findall(html_content))

    if aggressive:
        compressed = PIXEL_ART_TR_PATTERN.sub(
            _compress_tr_aggressive, html_content
        )
    else:
        compressed = PIXEL_ART_SEQUENCE_PATTERN.sub(
            _compress_sequence_safari_safe, html_content
        )

    td_after = len(ALL_TD_TAG_PATTERN.findall(compressed))

    stats = {
        "bytes_before": len(html_content),
        "bytes_after": len(compressed),
        "td_before": td_before,
        "td_after": td_after,
    }

    return compressed, stats
