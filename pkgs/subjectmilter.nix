{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule rec {
  pname = "subjectmilter";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "griff";
    repo = "subjectmilter";
    rev = "f4ffee163e89cd4096449c4d612fcb83c624a5ea";
    sha256 = "1gia12wvnfg7n4f3lphyfdj3z59dzbb1hwyqd8q466k5pm5xcg98";
  };

  vendorSha256 = "1mlil79zb3m7d5q3qjvjikmzq7w7i4cyrhi1pkw5qv2bp8zmcwjj";

  subPackages = [ "." ];

  deleteVendor = true;

  runVend = true;

  meta = with lib; {
    description = "Milter to support notls using subject, written in Go";
    homepage = "https://github.com/griff/subjectmilter";
    license = licenses.mit;
    #maintainers = with maintainers; [ kalbasit ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}