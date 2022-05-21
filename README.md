# agenix - [age](https://github.com/FiloSottile/age)-encrypted secrets for NixOS

`agenix` is a commandline tool for managing secrets encrypted with your existing SSH keys. This project also includes the NixOS module `age` for adding encrypted secrets into the Nix store and decrypting them.

## Contents

* [Problem and solution](#problem-and-solution)
* [Features](#features)
* [Installation](#installation)
  * [niv](#install-via-niv) (Current recommendation)
    * [module](#install-module-via-niv)
    * [CLI](#install-cli-via-niv)
  * [nix-channel](#install-via-nix-channel)
    * [module](#install-module-via-nix-channel)
    * [CLI](#install-cli-via-nix-channel)
  * [fetchTarball](#install-via-fetchtarball)
    * [module](#install-module-via-fetchtarball)
    * [CLI](#install-cli-via-fetchTarball)
  * [flakes](#install-via-flakes)
    * [module](#install-module-via-flakes)
    * [CLI](#install-cli-via-flakes)
* [Tutorial](#tutorial)
* [Community and Support](#community-and-support)
* [Rekeying](#rekeying)
* [Don't symlink secret](#dont-symlink-secret)
* [Use other implementations](#use-other-implementations)
* [Threat model/Warnings](#threat-modelwarnings)
* [Acknowledgements](#acknowledgements)

## Problem and solution

All files in the Nix store are readable by any system user, so it is not a suitable place for including cleartext secrets. Many existing tools (like NixOps deployment.keys) deploy secrets separately from `nixos-rebuild`, making deployment, caching, and auditing more difficult. Out-of-band secret management is also less reproducible.

`agenix` solves these issues by using your pre-existing SSH key infrastructure and `age` to encrypt secrets into the Nix store. Secrets are decrypted using an SSH host private key during NixOS system activation.

## Features

* Secrets are encrypted with SSH keys
  * system public keys via `ssh-keyscan`
  * can use public keys available on GitHub for users (for example, https://github.com/ryantm.keys)
* No GPG
* Very little code, so it should be easy for you to audit
* Encrypted secrets are stored in the Nix store, so a separate distribution mechanism is not necessary

## Notices

* Password-protected ssh keys: since the underlying tool age/rage do not support ssh-agent, password-protected ssh keys do not work well. For example, if you need to rekey 20 secrets you will have to enter your password 20 times.

## Installation

Choose one of the following methods:

* [niv](#install-via-niv) (Current recommendation)
* [nix-channel](#install-via-nix-channel)
* [fetchTarball](#install-via-fetchTarball)
* [flakes](#install-via-flakes)

### Install via [niv](https://github.com/nmattia/niv)

First add it to niv:

```ShellSession
$ niv add ryantm/agenix
```

#### Install module via niv

Then add the following to your `configuration.nix` in the `imports` list:

```nix
{
  imports = [ "${(import ./nix/sources.nix).agenix}/modules/age.nix" ];
}
```

#### Install CLI via niv

To install the `agenix` binary:

```nix
{
  environment.systemPackages = [ (pkgs.callPackage "${(import ./nix/sources.nix).agenix}/pkgs/agenix.nix" {}) ];
}
```

### Install via nix-channel

As root run:

```ShellSession
$ sudo nix-channel --add https://github.com/ryantm/agenix/archive/main.tar.gz agenix
$ sudo nix-channel --update
```

#### Install module via nix-channel

Then add the following to your `configuration.nix` in the `imports` list:

```nix
{
  imports = [ <agenix/modules/age.nix> ];
}
```

#### Install CLI via nix-channel

To install the `agenix` binary:

```nix
{
  environment.systemPackages = [ (pkgs.callPackage <agenix/pkgs/agenix.nix> {}) ];
}
```

### Install via fetchTarball

#### Install module via fetchTarball

Add the following to your configuration.nix:

```nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz"}/modules/age.nix" ];
}
```

  or with pinning:

```nix
{
  imports = let
    # replace this with an actual commit id or tag
    commit = "298b235f664f925b433614dc33380f0662adfc3f";
  in [
    "${builtins.fetchTarball {
      url = "https://github.com/ryantm/agenix/archive/${commit}.tar.gz";
      # replace this with an actual hash
      sha256 = "0000000000000000000000000000000000000000000000000000";
    }}/modules/age.nix"
  ];
}
```

#### Install CLI via fetchTarball

To install the `agenix` binary:

```nix
{
  environment.systemPackages = [ (pkgs.callPackage "${builtins.fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz"}/pkgs/agenix.nix" {}) ];
}
```

### Install via Flakes

#### Install module via Flakes

```nix
{
  inputs.agenix.url = "github:ryantm/agenix";
  # optional, not necessary for the module
  #inputs.agenix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, agenix }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      # change to your system:
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        agenix.nixosModule
      ];
    };
  };
}
```

#### Install CLI via Flakes

You don't need to install it,

```ShellSession
nix run github:ryantm/agenix -- --help
```

but, if you want to (change the system based on your system):

```nix
{
  environment.systemPackages = [ agenix.defaultPackage.x86_64-linux ];
}
```

## Tutorial

1. The system you want to deploy secrets to should already exist and
   have `sshd` running on it so that it has generated SSH host keys in
   `/etc/ssh/`.

2. Make a directory to store secrets and `secrets.nix` file for listing secrets and their public keys:

   ```ShellSession
   $ mkdir secrets
   $ cd secrets
   $ touch secrets.nix
   ```
3. Add public keys to `secrets.nix` file (hint: use `ssh-keyscan` or GitHub (for example, https://github.com/ryantm.keys)):
   ```nix
   let
     user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0idNvgGiucWgup/mP78zyC23uFjYq0evcWdjGQUaBH";
     user2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI6jSq53F/3hEmSs+oq9L4TwOo1PrDMAgcA1uo1CCV/";
     users = [ user1 user2 ];

     system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJDyIr/FSz1cJdcoW69R+NrWzwGK/+3gJpqD1t8L2zE";
     system2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzxQgondgEYcLpcPdJLrTdNgZ2gznOHCAxMdaceTUT1";
     systems = [ system1 system2 ];
   in
   {
     "secret1.age".publicKeys = [ user1 system1 ];
     "secret2.age".publicKeys = users ++ systems;
   }
   ```
4. Edit secret files (these instructions assume your SSH private key is in ~/.ssh/):
   ```ShellSession
   $ agenix -e secret1.age
   ```
5. Add secret to a NixOS module config:
   ```nix
   age.secrets.secret1.file = ../secrets/secret1.age;
   ```
6. NixOS rebuild or use your deployment tool like usual.

   The secret will be decrypted to the value of `config.age.secrets.secret1.path` (`/run/agenix/secret1` by default). For per-secret options controlling ownership etc, see [modules/age.nix](modules/age.nix).

## Community and Support

Support and development discussion is available here on GitHub and
also through [Matrix](https://matrix.to/#/#agenix:nixos.org).

## Rekeying

If you change the public keys in `secrets.nix`, you should rekey your
secrets:

```ShellSession
$ agenix --rekey
```

To rekey a secret, you have to be able to decrypt it. Because of
randomness in `age`'s encryption algorithms, the files always change
when rekeyed, even if the identities do not. (This eventually could be
improved upon by reading the identities from the age file.)

## Don't symlink secret

If your secret cannot be a symlink, you should set the `symlink` option to `false`:

```nix
{
  age.secrets.some-secret = {
    file = ./secret;
    path = "/var/lib/some-service/some-secret";
    symlink = false;
  };
}
```

Instead of first decrypting the secret to `/run/agenix` and then symlinking to its `path`, the secret will instead be forcibly moved to its `path`. Please note that, currently, there are no cleanup mechanisms for secrets that are not symlinked by agenix.

## Use other implementations

This project uses the Rust implementation of age, [rage](https://github.com/str4d/rage), by default. You can change it to use the [official implementation](https://github.com/FiloSottile/age).

### Module

```nix
{
  age.ageBin = "${pkgs.age}/bin/age";
}
```

### CLI

```nix
{
  environment.systemPackages = [
    (agenix.defaultPackage.x86_64-linux.override { ageBin = "${pkgs.age}/bin/age"; })
  ];
}
```

## YubiKey Support

There is now a rage plugin to allow for encrypting age files with a YubiKey.
Agenix offers preliminary support for this use case.

For ease of use, the required `age-plugin-yubikey` binary is included in the
agenix devshell.

Be sure to setup your YubiKey as outlined in the official
[plugin instructions][yk-plugin].

#### Warning
> A pin policy of 'never' may be used to avoid being asked for a PIN at
> activation time. However, this will give anyone with physical access to your
> yubikey the power to decrypt your secrets without a PIN.

Once you have a proper key generated, run `age-plugin-yubikey -i > yubi_id`
to save the identity for the key. Consider the `recipient` as the public key,
set it accordingly in `secrets.nix`, and invoke agenix as
`agenix -i yubi_id # ...` to target the yubikey identity.

To decrypt secrets properly at activation time, be sure to also set:
```nix
{
  age.sshKeyPaths = [ "${self}/path/to/age-plugin-yubikey-identity" ];
}
```

## Threat model/Warnings

This project has not been audited by a security professional.

People unfamiliar with `age` might be surprised that secrets are not
authenticated. This means that every attacker that has write access to
the secret files can modify secrets because public keys are exposed.
This seems like not a problem on the first glance because changing the
configuration itself could expose secrets easily. However, reviewing
configuration changes is easier than reviewing random secrets (for
example, 4096-bit rsa keys). This would be solved by having a message
authentication code (MAC) like other implementations like GPG or
[sops](https://github.com/Mic92/sops-nix) have, however this was left
out for simplicity in `age`.

### builtins.readFile anti-pattern

```nix
{
  # Do not do this!
  config.password = builtins.readFile config.age.secrets.secret1.path;
}
```

This can cause the cleartext to be placed into the world-readable Nix
store. Instead, have your services read the cleartext path at runtime.

## Acknowledgements

This project is based off of [sops-nix](https://github.com/Mic92/sops-nix) created Mic92. Thank you to Mic92 for inspiration and advice.

[yk-plugin]: https://github.com/str4d/age-plugin-yubikey#configuration
