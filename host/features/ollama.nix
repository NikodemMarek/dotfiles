{config, ...}: {
  services.ollama = {
    enable = true;
    port = 5090;
    host = "127.0.0.1";
    home = "/var/lib/ollama";
    models = "${config.services.ollama.home}/models";
    loadModels = [
      "llama3:latest"
    ];
  };

  persist.generated.directories = [
    config.services.ollama.models
  ];
}
