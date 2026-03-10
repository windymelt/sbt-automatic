# sbt-automatic

A zsh plugin that automatically starts an sbt server when you `cd` into an sbt project directory, and stops it when you leave or exit the shell.

Multiple terminal sessions sharing the same project are reference-counted, so the server stays alive until the last session exits.

## Requirements

- zsh
- sbt

## Installation

### zinit

```zsh
zinit light windymelt/sbt-automatic
```

### zplug

```zsh
zplug "windymelt/sbt-automatic"
```

### sheldon

Add the following to `~/.config/sheldon/plugins.toml`:

```toml
[plugins.sbt-automatic]
github = "windymelt/sbt-automatic"
```

### Oh My Zsh

```sh
git clone https://github.com/windymelt/sbt-automatic.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sbt-automatic
```

Then add `sbt-automatic` to the `plugins` array in `~/.zshrc`:

```zsh
plugins=(... sbt-automatic)
```

### Manual

Clone the repository and source the plugin in your `~/.zshrc`:

```sh
git clone https://github.com/windymelt/sbt-automatic.git ~/sbt-automatic
echo 'source ~/sbt-automatic/sbt-automatic.plugin.zsh' >> ~/.zshrc
```

## Log

sbt output is logged to `.sbt-automatic-log` in the project root directory. You may want to add it to your global gitignore:

```sh
echo '.sbt-automatic-log' >> ~/.config/git/ignore
```

## License

BSD 3-Clause License
