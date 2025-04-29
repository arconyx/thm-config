{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  zlib,
  versionCheckHook,
  lib,
  alsa-lib,
  xorg,
  ...
}:

stdenv.mkDerivation {
  pname = "graalvm-ee";
  version = "24+36-jvmci-b01";

  src = fetchurl {
    url = "https://download.oracle.com/graalvm/24/archive/graalvm-jdk-24_linux-x64_bin.tar.gz";
    sha256 = "04mhvzrhcxmj1q9y10a6aym19awzhiagf24h1lg0917gnjkp2mxf";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    glibc
    zlib
    alsa-lib # libasound.so wanted by lib/libjsound.so
    (lib.getLib stdenv.cc.cc) # libstdc++.so.6
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/java";

  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';

  meta = with lib; {
    description = "GraalVM Enterprise Edition 24 - High-performance polyglot virtual machine";
    homepage = "https://www.graalvm.org/";
    license = licenses.unfreeRedistributable;
    platforms = platforms.linux;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "java";
  };
}
