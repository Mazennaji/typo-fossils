# typo-fossils

![typo-fossils logo](assets/logo.png)

**Your mistakes, fossilized into a personal autocorrect dictionary.**

typo-fossils reads your own writing, finds the misspellings you repeat, and exports them as ready-to-use snippets for Espanso, Vim, and macOS text replacement. Generic autocorrect fixes everyone's typos. This fixes yours.

![Perl](https://img.shields.io/badge/Perl-5.20+-39457E?style=for-the-badge&logo=perl&logoColor=white)
![CLI](https://img.shields.io/badge/Interface-CLI-1f2937?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Early%20Development-f59e0b?style=for-the-badge)
![Tests](https://img.shields.io/badge/Tests-prove-22c55e?style=for-the-badge&logo=perl&logoColor=white)

![Espanso](https://img.shields.io/badge/Export-Espanso-8b5cf6?style=for-the-badge)
![Vim](https://img.shields.io/badge/Export-Vim-019733?style=for-the-badge&logo=vim&logoColor=white)
![macOS](https://img.shields.io/badge/Export-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)

## Why typo-fossils

Most people misspell the same 20 to 30 words over and over. Built-in autocorrect is trained on everyone, so it misses the patterns that are specific to you. The evidence is already sitting in your notes, drafts, and exported emails. typo-fossils digs it out.

- **Personal by design.** The dictionary is built from your text, not a generic word list.
- **Frequency-aware.** Words you use often are treated as correct. Rare near-duplicates of them are the suspects.
- **Ranked, not guessed.** Every candidate gets a confidence score so you review the strongest ones first.
- **Export anywhere.** One run produces snippets for the tools you already use.
- **Local and private.** Your text never leaves your machine.

## How it works

1. **Ingest.** Read plain text and Markdown files from a path you provide.
2. **Tokenize.** Normalize Unicode, lowercase, and split into words.
3. **Count.** Build a word-frequency table across the whole corpus.
4. **Detect.** Flag rare words within a small edit distance of a common word, such as `teh` against `the`.
5. **Score.** Rank each suspect by how often it appears and how close it sits to its likely correction.
6. **Export.** Write the confirmed pairs in the format your tool expects.

## Quick start

```
cpanm --installdeps .
prove -l t
perl bin/typo-fossils --version
```

## Planned usage

The command surface below is the target design and is not implemented yet.

```
typo-fossils scan ~/notes --min-count 3 --max-distance 2
typo-fossils review
typo-fossils export --format espanso --out typos.yml
typo-fossils export --format vim --out typos.vim
typo-fossils export --format macos --out typos.plist
typo-fossils stats
```

## Export formats

**Espanso**

```yaml
matches:
  - trigger: "teh"
    replace: "the"
  - trigger: "recieve"
    replace: "receive"
```

**Vim**

```vim
iabbrev teh the
iabbrev recieve receive
```

**macOS text replacement**

A property list of phrase and shortcut pairs that can be imported into System Settings.

## Architecture

![System architecture](assets/architecture.png)

The pipeline is a sequence of small, independently testable stages. Each stage takes plain Perl data structures in and returns them out, so stages can be tested in isolation and swapped without touching the rest.

| Stage | Responsibility |
| --- | --- |
| Reader | Walks input paths and streams file contents |
| Tokenizer | Unicode normalization and word splitting |
| Counter | Builds the frequency table |
| Detector | Finds near-miss pairs using edit distance |
| Scorer | Assigns confidence and ranks candidates |
| Exporter | Renders Espanso, Vim, and macOS output |

## Tech stack

![Perl](https://img.shields.io/badge/Perl-39457E?style=flat-square&logo=perl&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)
![Markdown](https://img.shields.io/badge/Markdown-000000?style=flat-square&logo=markdown&logoColor=white)
![Vim](https://img.shields.io/badge/Vim-019733?style=flat-square&logo=vim&logoColor=white)
![Apple](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)

| Concern | Choice |
| --- | --- |
| Language | Perl 5.20+ |
| CLI parsing | Getopt::Long |
| Similarity | Text::Levenshtein |
| Testing | Test::More with prove |
| Dependencies | cpanm with cpanfile |

## Project structure

```
bin/typo-fossils      command-line entry point
lib/Typo/Fossils.pm   core module
t/                    test suite
cpanfile              dependency manifest
```

## Roadmap

- [x] Project skeleton, version flag, and test harness
- [ ] Tokenizer with Unicode normalization
- [ ] Word-frequency table
- [ ] Edit-distance typo detection
- [ ] Confidence scoring and ranking
- [ ] Interactive review
- [ ] Espanso, Vim, and macOS exporters
- [ ] Keyboard-adjacency model to separate slips from spelling gaps
- [ ] Typo history and improvement tracking
- [ ] Typo hall of fame report

## Contributing

Issues and pull requests are welcome. Run `prove -l t` before submitting and keep each change focused on one stage of the pipeline.