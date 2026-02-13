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
    "age1l48gfpefgh5p4phelwc760pg24pm6qwxju2zlxcgvcamw6pzjgrqq8r3g3"
    "age10kwzaeajuyvfuyuh03tk6ywand899699rdxlrskh2f6x6ru9t56s02d6pg"
    "age1yyrhr0zpg3xnxtstq6g3u0zrxglfhnur6387f5znwmehg36rh4cs39apxy"
  ];
  "joshsymonds" = [
    "age1yyrhr0zpg3xnxtstq6g3u0zrxglfhnur6387f5znwmehg36rh4cs39apxy"
  ];
}
