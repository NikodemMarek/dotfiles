{inputs, ...}: {
  nixGL = {
    packages = inputs.nixGL.packages;
    defaultWrapper = "mesa";
    offloadWrapper = "nvidiaPrime";
  };
}
