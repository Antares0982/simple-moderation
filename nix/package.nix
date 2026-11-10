{
  lib,
  stdenvNoCC,
  python313,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "simple-moderation";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../simple_moderation.py
      ../test_moderation.py
    ];
  };
  nativeBuildInputs = [
    python313
    makeWrapper
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python test_moderation.py
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 simple_moderation.py "$out/lib/simple-moderation/simple_moderation.py"
    makeWrapper ${python313}/bin/python "$out/bin/simple-moderation" \
      --add-flags "$out/lib/simple-moderation/simple_moderation.py"
    runHook postInstall
  '';
  meta = {
    description = "DeepSeek image and text moderation";
    mainProgram = "simple-moderation";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
