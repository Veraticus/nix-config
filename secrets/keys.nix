# Map hostnames or operator machines to the age recipients that may decrypt secrets.
# Populate with age public keys (e.g., from `age-keygen` or `ssh-to-age`).
#
# Example:
# {
#   "vermissian" = [
#     "age1examplepublickey..."
#   ];
#   "macbook" = [
#     "age1anotherpublickey..."
#   ];
# }
{
  "vermissian" = [
    "age1gk07t276expcprxg4el8rsmap4ry3vq9ungmhs9ap3rtwljge9qsqdvnkw"
    "age10kwzaeajuyvfuyuh03tk6ywand899699rdxlrskh2f6x6ru9t56s02d6pg"
  ];
  "ultraviolet" = [
    "age196jc6pzxuy5hg89yezjpv8wy3jt2s3fs0r7ntfe0vrqwq80mr5jq9rdpsz"
    "age10kwzaeajuyvfuyuh03tk6ywand899699rdxlrskh2f6x6ru9t56s02d6pg"
    "age1yyrhr0zpg3xnxtstq6g3u0zrxglfhnur6387f5znwmehg36rh4cs39apxy"
  ];
  "joshsymonds" = [
    "age1yyrhr0zpg3xnxtstq6g3u0zrxglfhnur6387f5znwmehg36rh4cs39apxy"
  ];
}
