{
  lib,
  buildGo123Module,
  fetchFromGitHub,
  nix-update-script,
}:
buildGo123Module {
  pname = "fabric-ai";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "danielmiessler";
    repo = "fabric";
    rev = "9b8871f25b17dfeb7338ebaf39078bb0929b0fb9";
    hash = "sha256-tgcX+ljottUU+oRqH4m5coiZBn7/2cV03/2yEEG5Nlk=";
  };

  vendorHash = "sha256-CHgeHumWtNt8SrbzzCWqBdLxTmmyDD2bfLkriPeez2E=";

  ldflags = [
    "-s"
    "-w"
  ];

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Fabric is an open-source framework for augmenting humans using AI. It provides a modular framework for solving specific problems using a crowdsourced set of AI prompts that can be used anywhere";
    homepage = "https://github.com/danielmiessler/fabric";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [jaredmontoya];
    mainProgram = "fabric";
  };
}
