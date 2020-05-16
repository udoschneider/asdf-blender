<div align="center">

# asdf-blender ![Build](https://github.com/udoschneider/asdf-blender/workflows/Build/badge.svg) ![Lint](https://github.com/udoschneider/asdf-blender/workflows/Lint/badge.svg)

[blender](https://github.com/blender/blender) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Why?](#why)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add blender
# or
asdf plugin add https://github.com/udoschneider/asdf-blender.git
```

blender:

```shell
# Show all installable versions
asdf list-all blender

# Install specific version
asdf install blender latest

# Set a version globally (on your ~/.tool-versions file)
asdf global blender latest

# Now blender commands are available
blender --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/udoschneider/asdf-blender/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Udo Schneider](https://github.com/udoschneider/)
