{ stdenv, zlib, lib
, fetchurl
, autoPatchelfHook
}:
stdenv.mkDerivation rec {
  pname = "platform-tools";
  version = "1.39";

  src = fetchurl {
    url = "https://github.com/solana-labs/platform-tools/releases/download/v${version}/platform-tools-linux-x86_64.tar.bz2";
    hash = "sha256-qqjzadIKmF8jd/8mumjdsAJukwDEJuDd2lViYkYeGV0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    addAutoPatchelfSearchPath rust/lib
    addAutoPatchelfSearchPath llvm/lib
    install -m755 -D rust/lib/librustc_driver-7e7020e948cbeb5e.so $out/lib/librustc_driver-7e7020e948cbeb5e.so
    install -m755 -D rust/lib/libstd-6fcf4d73823f8a3e.so $out/lib/libstd-6fcf4d73823f8a3e.so

    install -m755 -D rust/bin/cargo $out/bin/cargo
    install -m755 -D rust/bin/rustc $out/bin/rustc
    install -m755 -D rust/bin/rustdoc $out/bin/rustdoc

    install -m755 -D llvm/bin/clang-16 $out/bin/clang-16
    install -m755 -D llvm/bin/clang-16 $out/bin/clang
    install -m755 -D llvm/bin/clang-16 $out/bin/clang++
    install -m755 -D llvm/bin/clang-16 $out/bin/clang-cl
    install -m755 -D llvm/bin/clang-16 $out/bin/clang-cpp

    install -m755 -D llvm/bin/llc $out/bin/llc
    install -m755 -D llvm/bin/lld $out/bin/lld
    install -m755 -D llvm/bin/lld $out/bin/ld.lld
    install -m755 -D llvm/bin/lld $out/bin/ld64.lld
    install -m755 -D llvm/bin/lld $out/bin/lld-link

    install -m755 -D llvm/bin/lldb_commands $out/bin/lldd_commands
    install -m755 -D llvm/bin/lldb_lookup.py $out/bin/lldd_lookup.py
    install -m755 -D llvm/bin/lldb_providers.py $out/bin/lldd_providers.py
    install -m755 -D llvm/bin/lldb-vscode $out/bin/lldd-vscode

    install -m755 -D llvm/bin/llvm-ar $out/bin/llvm-ar
    install -m755 -D llvm/bin/llvm-objcopy $out/bin/llvm-objcopy
    install -m755 -D llvm/bin/llvm-objdump $out/bin/llvm-objdump
    install -m755 -D llvm/bin/llvm-readobj $out/bin/llvm-readobj
    install -m755 -D llvm/bin/llvm-readobj $out/bin/llvm-readelf

    install -m755 -D llvm/bin/rust_types.py $out/bin/rust_types.py
    install -m755 -D llvm/bin/solana_commands $out/bin/solana_commands
    install -m755 -D llvm/bin/solana-lldb $out/bin/solana-lldb
    install -m755 -D llvm/bin/solana_lookup.py $out/bin/solana_lookup.py
    install -m755 -D llvm/bin/solana_providers.py $out/bin/solana_providers.py
    install -m755 -D llvm/bin/solana_types.py $out/bin/solana_types.py

    runHook postInstall
  '';

  meta = with lib; {
    description = "Solana Platform Tools";
  };
}
