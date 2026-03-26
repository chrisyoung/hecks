# HecksDomain

The build layer — compiles domain definitions into usable artifacts.

Takes the IR from HecksModel and produces generated Ruby gems, documentation, migrations, glossaries, and visualizations. Also handles importing domains from event storm formats.

## Sub-areas

- **domain/** — Compiler, Glossary, Migrations, Visualizer, DslSerializer, ReadmeGenerator, Versioner, Inspector
- **generators/** — AggregateGenerator, CommandGenerator, SpecGenerator, OpenApiGenerator, JsonSchemaGenerator, etc.
- **event_storm/** — Parser (Markdown), YamlParser, DomainBuilder, DslGenerator
- **extensions/docs.rb** — Extension metadata for documentation generation
