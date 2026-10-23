"""Template helpers shared by rebuild_compose.py and render_canvas_runtime.py."""

import re

_CONDITIONAL_BLOCK = re.compile(
    r'^[ \t]*(?://|#)\s*#IF\s+(<[A-Z_]+>)\s*\n'
    r'(.*?)'
    r'(?:^[ \t]*(?://|#)\s*#ELSE\s*\n(.*?))?'
    r'^[ \t]*(?://|#)\s*#ENDIF\s+\1\s*\n',
    re.MULTILINE | re.DOTALL,
)


def process_conditional_blocks(content, replacement_values):
    """Process #IF/#ELSE/#ENDIF conditional blocks in template content.

    Syntax (comment style adapts to the file type):
      // #IF <PLACEHOLDER>    (or # #IF <PLACEHOLDER> for YAML/shell)
      ...kept when <PLACEHOLDER> is non-empty...
      // #ELSE
      ...kept when <PLACEHOLDER> is empty...
      // #ENDIF <PLACEHOLDER>

    The #ELSE section is optional. Directive lines themselves are always removed
    from the output regardless of which branch is kept."""

    def _replace(m):
        placeholder = m.group(1)
        if_block = m.group(2)
        else_block = m.group(3) or ""
        value = replacement_values.get(placeholder, "")
        if value:
            return if_block
        return else_block

    return _CONDITIONAL_BLOCK.sub(_replace, content)
