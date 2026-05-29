import koi/types
import koi/widgets/section

template treeNode*(label: string, expanded: var bool, body: untyped) =
  if sectionHeader(label, expanded):
    body

template treeNode*(label: string, expanded: var bool, tooltip: string, body: untyped) =
  if sectionHeader(label, expanded, tooltip):
    body

template treeNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    body: untyped,
) =
  if sectionHeader(label, expanded, tooltip, style):
    body

template treeSubNode*(label: string, expanded: var bool, body: untyped) =
  if subSectionHeader(label, expanded):
    body

template treeSubNode*(
    label: string, expanded: var bool, tooltip: string, body: untyped
) =
  if subSectionHeader(label, expanded, tooltip):
    body

template treeSubNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    body: untyped,
) =
  if subSectionHeader(label, expanded, tooltip, style):
    body
