{{ range .Versions }}
<a name="{{ .Tag.Name }}"></a>
## {{ if .Tag.Previous }}[{{ .Tag.Name }}]{{ else }}{{ .Tag.Name }}{{ end }} - {{ datetime "2006-01-02" .Tag.Date }}

{{ range .CommitGroups -}}
### {{ .Title }}

{{ range .Commits -}}
- {{ if .Scope }}**{{ .Scope }}:** {{ end }}{{ .Subject }}{{ if .References }} ({{ range $i, $ref := .References }}{{ if $i }}, {{ end }}#{{ $ref.Ref }}{{ end }}){{ end }}
{{ end }}
{{ end -}}

{{- if .NoteGroups -}}
{{ range .NoteGroups -}}
### {{ .Title }}

{{ range .Notes }}
{{ .Body }}
{{ end }}
{{ end -}}
{{ end -}}

{{ if .Tag.Previous -}}
**Full Changelog**: https://github.com/maxrantil/protonvpn-manager/compare/{{ .Tag.Previous.Name }}...{{ .Tag.Name }}
{{ end -}}

{{ end -}}
