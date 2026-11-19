{
  runCommand,
  makeWrapper,
  runtimeShell,

  wikiPhp,
  wikiPkg,
  wikiUser,
  wikiConfig,

}:
runCommand "mediawiki-scripts"
  {
    nativeBuildInputs = [ makeWrapper ];
    preferLocalBuild = true;
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${wikiPhp}/bin/php $out/bin/mediawiki-maintenance \
      --set MEDIAWIKI_CONFIG ${wikiConfig} \
      --add-flags ${wikiPkg}/share/mediawiki/maintenance/run.php

    for i in changePassword createAndPromote deleteUserEmail renameUser resetUserEmail userOptions edit nukePage update importDump run; do
      script="$out/bin/mediawiki-$i"
    cat <<'EOF' >"$script"
    #!${runtimeShell}
    become=(exec)
    if [[ "$(id -u)" != ${wikiUser} ]]; then
      become=(exec /run/wrappers/bin/sudo -u ${wikiUser} --)
    fi
    "${"$"}{become[@]}" ${placeholder "out"}/bin/mediawiki-maintenance \
    EOF
      if [[ "$i" != "run" ]]; then
        echo "  ${wikiPkg}/share/mediawiki/maintenance/$i.php \"\$@\"" >>"$script"
      else
        echo "  ${wikiPkg}/share/mediawiki/maintenance/\$1.php \"\''${@:2}\"" >>"$script"
      fi
      chmod +x "$script"
    done
  ''
