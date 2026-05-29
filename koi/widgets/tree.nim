import koi/types
import koi/defaults
import koi/widgets/section

template treeNodeImpl(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    isDisabled: bool,
    body: untyped,
) =
  if sectionHeader(label, expanded, tooltip, style, disabled = isDisabled):
    body

template treeNode*(label: string, expanded: var bool, body: untyped) =
  treeNodeImpl(
    label, expanded, "", borrowDefaultSectionHeaderStyle(), isDisabled = false
  ):
    body

template treeNode*(label: string, expanded: var bool, disabled: bool, body: untyped) =
  treeNodeImpl(label, expanded, "", borrowDefaultSectionHeaderStyle(), disabled):
    body

template treeNode*(label: string, expanded: var bool, tooltip: string, body: untyped) =
  treeNodeImpl(label, expanded, tooltip, borrowDefaultSectionHeaderStyle(), false):
    body

template treeNode*(
    label: string, expanded: var bool, tooltip: string, disabled: bool, body: untyped
) =
  treeNodeImpl(label, expanded, tooltip, borrowDefaultSectionHeaderStyle(), disabled):
    body

template treeNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    body: untyped,
) =
  treeNodeImpl(label, expanded, tooltip, style, false):
    body

template treeNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    disabled: bool,
    body: untyped,
) =
  treeNodeImpl(label, expanded, tooltip, style, disabled):
    body

template treeSubNodeImpl(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    isDisabled: bool,
    body: untyped,
) =
  if subSectionHeader(label, expanded, tooltip, style, disabled = isDisabled):
    body

template treeSubNode*(label: string, expanded: var bool, body: untyped) =
  treeSubNodeImpl(
    label, expanded, "", borrowDefaultSubSectionHeaderStyle(), isDisabled = false
  ):
    body

template treeSubNode*(
    label: string, expanded: var bool, disabled: bool, body: untyped
) =
  treeSubNodeImpl(label, expanded, "", borrowDefaultSubSectionHeaderStyle(), disabled):
    body

template treeSubNode*(
    label: string, expanded: var bool, tooltip: string, body: untyped
) =
  treeSubNodeImpl(label, expanded, tooltip, borrowDefaultSubSectionHeaderStyle(), false):
    body

template treeSubNode*(
    label: string, expanded: var bool, tooltip: string, disabled: bool, body: untyped
) =
  treeSubNodeImpl(
    label, expanded, tooltip, borrowDefaultSubSectionHeaderStyle(), disabled
  ):
    body

template treeSubNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    body: untyped,
) =
  treeSubNodeImpl(label, expanded, tooltip, style, false):
    body

template treeSubNode*(
    label: string,
    expanded: var bool,
    tooltip: string,
    style: SectionHeaderStyle,
    disabled: bool,
    body: untyped,
) =
  treeSubNodeImpl(label, expanded, tooltip, style, disabled):
    body
