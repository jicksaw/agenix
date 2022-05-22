{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, pcsclite
, darwin
}:

rustPlatform.buildRustPackage rec {
  pname = "age-plugin-yubikey";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "str4d";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-KXqicTZ9GZlNj1AH3tMmOrC8zjXoEnqo4JJJTBdiI4E=";
  };

  cargoSha256 = "sha256-m/v4E7KHyLIWZHX0TKpqwBVDDwLjhYpOjYMrKEtx6/4=";

  nativeBuildInputs = lib.optionals stdenv.isLinux [ pkg-config ];

  buildInputs = lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [
      Foundation
      PCSC
    ]) ++ lib.optionals stdenv.isLinux [ pcsclite ];

  meta = with lib; {
    description = "YubiKey plugin for age";
    homepage = "https://github.com/str4d/${pname}";
    changelog = "https://github.com/str4d/${pname}/releases/tag/v${version}";
    license = with licenses; [ asl20 mit ]; # either at your option
    maintainers = with maintainers; [ nrdxp ];
  };
}
