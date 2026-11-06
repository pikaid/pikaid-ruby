# Official interoperability fixtures

These files are vendored, unmodified, from the official PHP implementation at
tag `v1.2.0` (commit `e3f843edeb5157a5d2d25196cac0d69580810a95`):

- `pikaid-v1.json`
  <https://github.com/pikaid/pikaid-php/blob/e3f843edeb5157a5d2d25196cac0d69580810a95/tests/vectors/pikaid-v1.json>
- `pikaid-v1.schema.json`
  <https://github.com/pikaid/pikaid-php/blob/e3f843edeb5157a5d2d25196cac0d69580810a95/tests/vectors/pikaid-v1.schema.json>

SHA-256:

```text
b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500  pikaid-v1.json
4441d4dbaa6c5450ae9cbfb2438c53bc0421bba2b7fcc9ef9b158e5d1de0759e  pikaid-v1.schema.json
```

The `pikaid-v1` filename is historical. The identifier format is immutable and
unversioned; the fixtures are independent interoperability inputs, not a
definition of the format. The normative definition is
[specification revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4).

The source fixtures are licensed under the MIT License; see the repository
`LICENSE`.
