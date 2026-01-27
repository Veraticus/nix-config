_: {
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Josh Symonds";
        email = "josh@joshsymonds.com";
      };

      alias = {
        co = "checkout";
        st = "status";
        a = "add --all";
        pl = "pull -u";
        pu = "push --all origin";
      };

      core = {
        editor = "hx";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
      url."ssh://git@github.com/".insteadOf = "https://github.com/";
      pull = {rebase = true;};
      web = {browser = "firefox";};
      rerere = {
        enabled = 1;
        autoupdate = 1;
      };
      push = {default = "simple";};
    };
  };
}
