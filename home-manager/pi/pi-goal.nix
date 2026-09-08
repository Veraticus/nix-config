{pkgs}: let
  piGoalSource = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@narumitw/pi-goal/-/pi-goal-0.54.3.tgz";
    hash = "sha256-Zw+7QW0g4Xk5EXhCwkB+fBXxe5+3nsfNLAyVuzP6v78=";
  };

  piTuiKit = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@narumitw/pi-tui-kit/-/pi-tui-kit-0.59.0.tgz";
    hash = "sha256-dMzOHA7jxKShvU2okzNt7qRNm/5ONa+05ZkcfVTALbI=";
  };

  grokMermaid = pkgs.fetchzip {
    url = "https://registry.npmjs.org/grok-mermaid/-/grok-mermaid-0.2.3.tgz";
    hash = "sha256-tT9tKcotpywP98aI4H8AJZa6cikj9adGFZpialQ0Dxk=";
  };

  highlightJs = pkgs.fetchzip {
    url = "https://registry.npmjs.org/highlight.js/-/highlight.js-11.12.0.tgz";
    hash = "sha256-fcEJdFLzFkMR1rlm9sPVCr6A8YhUgm6+JNlLjMIrHk0=";
  };
in
  pkgs.runCommand "pi-goal-0.54.3" {} ''
    cp -r ${piGoalSource} $out
    chmod -R u+w $out
    patch -p1 -d $out < ${./pi-goal-goal-end.patch}
    mkdir -p $out/node_modules/@narumitw
    ln -s ${piTuiKit} $out/node_modules/@narumitw/pi-tui-kit
    ln -s ${grokMermaid} $out/node_modules/grok-mermaid
    ln -s ${highlightJs} $out/node_modules/highlight.js
    ln -s ${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/node_modules/typebox $out/node_modules/typebox
  ''
