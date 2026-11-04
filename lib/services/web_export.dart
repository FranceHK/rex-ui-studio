import 'dart:ui';

import '../models/ui_element.dart';
import 'export_common.dart';
import 'flutter_export.dart' show className;

/// One absolutely positioned web element, rendered either as HTML or JSX.
class WebNode {
  const WebNode(
    this.tag, {
    this.style = const {},
    this.attrs = const {},
    this.text,
    this.children = const [],
  });

  final String tag;

  /// CSS properties in kebab-case, e.g. {'background-color': '#FFF'}.
  final Map<String, String> style;
  final Map<String, String> attrs;
  final String? text;
  final List<WebNode> children;
}

const _iconFont =
    'https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded';

/// The screen as a tree of [WebNode]s (root = the artboard).
WebNode webTree(DesignPage page) => WebNode(
  'div',
  style: {
    'position': 'relative',
    'width': '${fmt(page.size.width)}px',
    'height': '${fmt(page.size.height)}px',
    'overflow': 'hidden',
    'background': hexColor(page.background),
    'font-family': 'system-ui, -apple-system, Roboto, sans-serif',
  },
  children: [for (final e in page.elements) _node(e)],
);

WebNode _node(UiElement e) {
  final r = e.rect;
  final box = {
    'position': 'absolute',
    'left': '${fmt(r.left)}px',
    'top': '${fmt(r.top)}px',
    'width': '${fmt(r.width)}px',
    'height': '${fmt(r.height)}px',
    'box-sizing': 'border-box',
  };
  final font = {
    'color': hexColor(e.textColor),
    'font-size': '${fmt(e.fontSize)}px',
    'font-weight': e.bold ? '600' : '400',
  };
  final align = switch (e.effectiveTextAlign) {
    TextAlign.center => 'center',
    TextAlign.right || TextAlign.end => 'right',
    _ => 'left',
  };
  final justify = switch (align) {
    'center' => 'center',
    'right' => 'flex-end',
    _ => 'flex-start',
  };
  final vertical = switch (e.vAlign) {
    VAlign.top => 'flex-start',
    VAlign.middle => 'center',
    VAlign.bottom => 'flex-end',
  };
  final flex = {
    'display': 'flex',
    'align-items': vertical,
    'justify-content': justify,
    'text-align': align,
  };
  final radius = {'border-radius': '${fmt(e.radius)}px'};

  WebNode icon(String name, Color color, [double? size]) => WebNode(
    'span',
    attrs: const {'class': 'material-symbols-rounded'},
    style: {
      'color': hexColor(color),
      if (size != null) 'font-size': '${fmt(size)}px',
    },
    text: snakeIcon(name),
  );

  return switch (e.type) {
    ElementType.text => WebNode(
      'div',
      style: {...box, ...flex, ...font},
      text: e.text,
    ),
    ElementType.button => WebNode(
      'button',
      style: {
        ...box,
        ...flex,
        ...font,
        ...radius,
        'background': hexColor(e.color),
        'border': 'none',
        'padding': '0 12px',
        'cursor': 'pointer',
      },
      text: e.text,
    ),
    ElementType.input => WebNode(
      'input',
      attrs: {'placeholder': e.text},
      style: {
        ...box,
        ...font,
        ...radius,
        'border': '1px solid ${hexColor(e.color)}',
        'padding': '0 14px',
        'background': 'transparent',
      },
    ),
    ElementType.image => WebNode(
      'div',
      style: {
        ...box,
        ..._shapeCss(e),
        'background': hexColor(e.color),
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'center',
      },
      children: [icon('image', e.textColor, r.shortestSide * 0.3)],
    ),
    ElementType.container => WebNode(
      'div',
      style: {...box, ..._shapeCss(e), 'background': hexColor(e.color)},
    ),
    ElementType.appBar => WebNode(
      'header',
      style: {
        ...box,
        ...font,
        'background': hexColor(e.color),
        'display': 'flex',
        'align-items': 'center',
        'gap': '16px',
        'padding': '0 16px',
      },
      children: [
        icon('menu', e.textColor),
        WebNode('span', text: e.text),
      ],
    ),
    ElementType.navBar => WebNode(
      'nav',
      style: {
        ...box,
        'background': hexColor(e.color),
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'space-around',
      },
      children: [
        for (final (i, n) in const [
          'home',
          'search',
          'favorite',
          'person',
        ].indexed)
          icon(n, i == 0 ? e.textColor : const Color(0xFF98A2B3)),
      ],
    ),
    ElementType.iconItem => WebNode(
      'div',
      style: {
        ...box,
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'center',
      },
      children: [icon(e.text, e.color, r.shortestSide)],
    ),
    ElementType.avatar => WebNode(
      'div',
      style: {
        ...box,
        ...font,
        'background': hexColor(e.color),
        'border-radius': '50%',
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'center',
      },
      text: e.text,
    ),
    ElementType.toggle => WebNode(
      'div',
      attrs: const {'role': 'switch', 'aria-checked': 'true'},
      style: {
        ...box,
        'background': hexColor(e.color),
        'border-radius': '${fmt(r.height / 2)}px',
      },
      children: [
        WebNode(
          'div',
          style: {
            'position': 'absolute',
            'top': '${fmt(r.height * 0.125)}px',
            'right': '${fmt(r.height * 0.125)}px',
            'width': '${fmt(r.height * 0.75)}px',
            'height': '${fmt(r.height * 0.75)}px',
            'border-radius': '50%',
            'background': '#FFFFFF',
          },
        ),
      ],
    ),
    ElementType.divider => WebNode(
      'hr',
      style: {
        ...box,
        'top': '${fmt(r.top + r.height / 2)}px',
        'height': '1px',
        'margin': '0',
        'border': 'none',
        'background': hexColor(e.color),
      },
    ),
  };
}

Map<String, String> _shapeCss(UiElement e) {
  if (shapePoints(e.shape) case final points?) {
    final list = points
        .map((p) => '${fmt(p.dx * 100)}% ${fmt(p.dy * 100)}%')
        .join(', ');
    return {'clip-path': 'polygon($list)'};
  }
  return {
    'border-radius': e.shape == ElementShape.ellipse
        ? '50%'
        : '${fmt(e.radius)}px',
  };
}

/// A standalone HTML page with inline styles.
String exportHtml(DesignPage page) {
  final b = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('  <meta charset="utf-8">')
    ..writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('  <title>${_html(page.name)}</title>')
    ..writeln('  <link rel="stylesheet" href="$_iconFont">')
    ..writeln('  <style>body { margin: 0; }</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('  <!-- ${page.device.name} — generated by Rexa UI Studio -->');
  _writeHtml(b, webTree(page), 1);
  b
    ..writeln('</body>')
    ..writeln('</html>');
  return b.toString();
}

const _voidTags = {'input', 'hr'};

void _writeHtml(StringBuffer b, WebNode n, int depth) {
  final pad = '  ' * depth;
  final attrs = [
    for (final MapEntry(:key, :value) in n.attrs.entries)
      '$key="${_html(value)}"',
    if (n.style.isNotEmpty)
      'style="${n.style.entries.map((e) => '${e.key}: ${e.value}').join('; ')}"',
  ].join(' ');
  final open = attrs.isEmpty ? '<${n.tag}>' : '<${n.tag} $attrs>';
  if (_voidTags.contains(n.tag)) {
    b.writeln('$pad$open');
  } else if (n.children.isEmpty) {
    b.writeln('$pad$open${_html(n.text ?? '')}</${n.tag}>');
  } else {
    b.writeln('$pad$open');
    for (final c in n.children) {
      _writeHtml(b, c, depth + 1);
    }
    b.writeln('$pad</${n.tag}>');
  }
}

/// A React function component with inline style objects.
String exportReact(DesignPage page) {
  final name = className(page.name);
  final b = StringBuffer()
    ..writeln('// ${page.device.name} — generated by Rexa UI Studio.')
    ..writeln(
      '// Icons use the Material Symbols Rounded font: <link rel="stylesheet" '
      'href="$_iconFont">',
    )
    ..writeln()
    ..writeln('export default function $name() {')
    ..writeln('  return (');
  _writeJsx(b, webTree(page), 2);
  b
    ..writeln('  );')
    ..writeln('}');
  return b.toString();
}

void _writeJsx(StringBuffer b, WebNode n, int depth) {
  final pad = '  ' * depth;
  String camel(String key) =>
      key.replaceAllMapped(RegExp(r'-([a-z])'), (m) => m[1]!.toUpperCase());
  String value(String v) => RegExp(r'^-?\d+(\.\d+)?px$').hasMatch(v)
      ? v.substring(0, v.length - 2)
      : "'${v.replaceAll("'", r"\'")}'";
  final attrs = [
    for (final MapEntry(:key, :value) in n.attrs.entries)
      '${key == 'class' ? 'className' : key}="${_html(value)}"',
    if (n.style.isNotEmpty)
      'style={{ ${n.style.entries.map((e) => '${camel(e.key)}: ${value(e.value)}').join(', ')} }}',
  ].join(' ');
  final open = attrs.isEmpty ? '<${n.tag}' : '<${n.tag} $attrs';
  if (_voidTags.contains(n.tag) ||
      (n.children.isEmpty && (n.text ?? '').isEmpty)) {
    b.writeln('$pad$open />');
  } else if (n.children.isEmpty) {
    b.writeln('$pad$open>${_jsxText(n.text!)}</${n.tag}>');
  } else {
    b.writeln('$pad$open>');
    for (final c in n.children) {
      _writeJsx(b, c, depth + 1);
    }
    b.writeln('$pad</${n.tag}>');
  }
}

String _html(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _jsxText(String v) =>
    _html(v).replaceAll('{', '&#123;').replaceAll('}', '&#125;');
