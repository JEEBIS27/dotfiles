# Generated from the shared jeebis desktop palette.
prSections:
  - title: My Pull Requests
    filters: is:open author:@me
  - title: Needs My Review
    filters: is:open review-requested:@me
  - title: Involved
    filters: is:open involves:@me -author:@me
issuesSections:
  - title: My Issues
    filters: is:open author:@me
  - title: Assigned
    filters: is:open assignee:@me
theme:
  colors:
    text:
      primary: "{{ foreground }}"
      secondary: "{{ bright_foreground }}"
      inverted: "{{ selection_foreground }}"
      faint: "{{ muted }}"
      warning: "{{ red }}"
      success: "{{ green }}"
      actor: "{{ cyan }}"
    background:
      selected: "{{ selection_background }}"
    border:
      primary: "{{ accent }}"
      secondary: "{{ muted }}"
      faint: "{{ lighter_background }}"
    inline:
      icons:
        newcontributor: "{{ cyan }}"
        contributor: "{{ blue }}"
        collaborator: "{{ yellow }}"
        member: "{{ green }}"
        owner: "{{ magenta }}"
        unknownrole: "{{ muted }}"
