{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "nbted";
  version = "1.5.2";

  src = fetchFromGitHub {
    owner = "C4K3";
    repo = "nbted";
    tag = finalAttrs.version;
    hash = "sha256-8f9NIWJB/ye67QkvfKnrTK1hUkTKs6FQiKk2z+XsdP8=";
  };

  cargoHash = "sha256-Vz4NF8wDpD0Hy6NzVBuLQC9t90hNeoNHuVdxMjPZEx4=";

  patches = [ ./nbted-git-rev.patch ];

  # half the tests are missing required datafiles in the upstream repo
  doCheck = false;

  meta = {
    description = "Command-line NBT editor written in Rust";
    homepage = "https://github.com/C4K3/nbted";
    license = lib.licenses.cc0;
  };
})
