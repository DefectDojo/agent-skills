# defectdojo-report

Security reporting from DefectDojo Pro data.

## Skill

**`security-report`** builds a report for a specific audience.

> Build the quarterly security report for the board.
> I need program health numbers for engineering leadership.

It establishes the audience first, because a board cut and an engineering cut
use different data and different framing. It pulls from the Pro insights
endpoints, uses API values verbatim, and refuses to describe a trend without
having fetched both ends of it.

It can also generate a native DefectDojo report artifact for download when the
output needs to look like it came from the security tool of record.

Requires DefectDojo Pro and `defectdojo-connect`, which installs automatically.
