{

  allowUnfree = true;

  packageOverrides = originalPackages: let newPackages = originalPackages.pkgs; in {

    #-------------#
    # qutebrowser #
    #-------------#
    #
    # override changes arguments to derivation (ex options and dependencies)
    # overrideAttrs changes the attrs of the actual derivation (ex version, build steps)
    #
    # qutebrowser = (originalPackages.qutebrowser.override {
    #   ##
    #   # fix qtwebkit-plugins so notifications and spellcheck work
    #   ##
    #   qtwebkit-plugins = originalPackages.libsForQt5.qtwebkit-plugins.overrideAttrs(oldAttrs: {
    #     postPatch = oldAttrs.postPatch + ''
    #       sed -i "s,plugin.h,plugin.h ${newPackages.qt5.qtwebkit.dev}/include/QtWebKit/qwebkitplatformplugin.h," src/src.pro
    #     '';
    #   });

    #   ##
    #   # qtwebengine
    #   ##
    #   pyqt5 = originalPackages.python3Packages.pyqt5.overrideAttrs(oldAttrs: {
    #     buildInputs = oldAttrs.buildInputs ++ [ originalPackages.qt5.qtwebengine originalPackages.nss ];
    #   });

    # }).overrideAttrs(oldAttrs: rec {
    #   ##
    #   # support spaces in keybindings by surrounding with quotes
    #   ##
    #   postPatch = oldAttrs.postPatch + ''
    #     sed -i 's,line = line.strip(),line = (lambda l: l[1:-1] if l.startswith("\\x22") and line.endswith("\\x22") else l)(line.strip()),' qutebrowser/config/parsers/keyconf.py
    #     sed -i "s,lines.append(' ' [*] 4 [+] k),lines.append(' ' * 4 + '\"' + k + '\"')," qutebrowser/config/parsers/keyconf.py
    #   '';
    # });

    #-------#
    # dunst #
    #-------#
    #
    # Use more recent version from git
    #
    dunst = originalPackages.dunst.overrideAttrs(oldAttrs: rec {
      version = assert oldAttrs.version == "1.1.0"; "1.1.0_1_3f5257f";
      name = "dunst-${version}";
      src = originalPackages.fetchFromGitHub {
        owner = "knopwob";
        repo = "dunst";
        rev = "3f5257f2853220fb9e3c51459446d576f5a580ac";
        sha256 = "0rycrddbj5lb8ykjb9b2f1vbzxax7maldxdbyxa1idi9y7924va7";
      };
      patches = [];
      buildInputs = oldAttrs.buildInputs ++ [ originalPackages.gnome2.gtk ];
    });

    #----#
    # hy #
    #----#
    #
    # use python3, use version 0.12.1
    # `doCheck = false` doesn't seem to work with override, so just redefine the
    # whole thing.
    #
    hy = originalPackages.python35Packages.buildPythonApplication rec {
      name = "hy-${version}";
      version = "0.12.1";
      src = originalPackages.fetchurl {
        url = "mirror://pypi/h/hy/${name}.tar.gz";
        sha256 = "1fjip998k336r26i1gpri18syvfjg7z46wng1n58dmc238wm53sx";
      };
      propagatedBuildInputs = with originalPackages.python35Packages; [ appdirs clint astor rply ];
      doCheck = false;
    };

    #----------------#
    # notify-desktop #
    #----------------#
    #
    notify-desktop = originalPackages.stdenv.mkDerivation rec {
      name = "notify-desktop-${version}";
      version = "0.2.0-9863919";
      src = originalPackages.fetchFromGitHub {
        owner = "nowrep";
        repo = "notify-desktop";
        rev = "9863919fb4ce7820810ac14a09a46ee73c3d56cc";
        sha256 = "1brcvl2fx0yzxj9mc8hzfl32zdka1f1bxpzsclcsjplyakyinr1a";
      };

      postPatch = ''substituteInPlace src/Makefile --replace "/usr/bin" "$out/bin"'';
      preInstall = ''mkdir -p $out/bin'';

      buildInputs = [originalPackages.pkgconfig originalPackages.dbus];
    };

    #--------#
    # deepms #
    #--------#
    #
    ddccontrol = originalPackages.ddccontrol.overrideAttrs( origAttrs: rec {
      postInstall = ''
        cp src/config.h $out/include/ddccontrol/config.h
      '';
    });

    deepms = originalPackages.stdenv.mkDerivation rec {
      name = "deepms-${version}";
      version = "0.0.1-76b87bb";
      src = originalPackages.fetchFromGitHub {
        owner = "pitkley";
        repo = "deepms";
        rev = "76b87bbb83b293d1ec570120a3a29f0b4dc76b23";
        sha256 = "1hi44gs83bx8g3597l7aib5xxljmxszjwfl1k91kca80hksq8kxm";
      };

      postPatch = ''
        echo -e '\nINSTALL(TARGETS deepms DESTINATION ''${CMAKE_INSTALL_PREFIX}/bin)' >> CMakeLists.txt
      '';
      buildInputs = with originalPackages; [ cmake newPackages.ddccontrol libxml2 x11 xorg.libXext ];
    };

    #-------------#
    # opencv-java #
    #-------------#
    opencv-java = (originalPackages.opencv3.override {
        enableFfmpeg = true;
        enableContrib = true;
    }).overrideAttrs( origAttrs: rec {
        name = "${origAttrs.name}-java";
        cmakeFlags = origAttrs.cmakeFlags ++ ["-DBUILD_SHARED_LIBS=OFF"];
        buildInputs = origAttrs.buildInputs ++ [ originalPackages.ant originalPackages.pythonPackages.python ];
        propagatedBuildInputs = origAttrs.propagatedBuildInputs ++ [ originalPackages.jdk ];
    });
    #----------------------------------------#
    # Packages installed in user environment #
    #----------------------------------------#
    #
    # update with:
    #   nix-env -uA --always nixos.pclenv
    #
    # sort with:
    #   v i [ SPC x l s
    #
    pclenv = with newPackages; buildEnv {
      name = "pclenv";

      # Sometimes docs are under -man, -doc, or -info dirs in /nix/store, which
      # seems to translate to attrs on the package. I don't know why or if there
      # is a better way to do this. Installing the package with `nix-env -i` or
      # even `nix-shell -p` usually includes the docs.
      paths = let
        catMeMaybe = x: attr: if builtins.hasAttr attr x then [(builtins.getAttr attr x)] else [];
        sections = ["man" "doc" "info"];
      in lib.concatMap (x: [x] ++ (lib.concatMap (catMeMaybe x) sections)) [
        ack
        acpi
        ag
        chromium
        compton
        #davmail
        dmenu2
        #docker
        dos2unix
        dtrx
        dunst
        dzen2
        emacs
        #firefox-bin
        git
        gnupg
        hsetroot
        htop
        imagemagick
        jdk
        jq
        lastpass-cli
        leiningen
        libnotify
        lsof
        mercurial
        mpv
        mu
        ncmpcpp
        nmap
        offlineimap
        p7zip
        pinentry
        pwgen
        python3
        qutebrowser
        rdesktop
        ruby
        rxvt_unicode
        scrot
        stow
        tcpdump
        traceroute
        unclutter
        unzip
        x11_ssh_askpass
        xclip
        xcompmgr
        xlibs.xdpyinfo
        xscreensaver
        zip
      ];
    };
  };
}