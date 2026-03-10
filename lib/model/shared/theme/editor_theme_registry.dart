import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/agate.dart';
import 'package:flutter_highlight/themes/an-old-hope.dart';
import 'package:flutter_highlight/themes/androidstudio.dart';
import 'package:flutter_highlight/themes/arduino-light.dart';
import 'package:flutter_highlight/themes/arta.dart';
import 'package:flutter_highlight/themes/ascetic.dart';
import 'package:flutter_highlight/themes/atelier-cave-dark.dart';
import 'package:flutter_highlight/themes/atelier-cave-light.dart';
import 'package:flutter_highlight/themes/atelier-dune-dark.dart';
import 'package:flutter_highlight/themes/atelier-dune-light.dart';
import 'package:flutter_highlight/themes/atelier-estuary-dark.dart';
import 'package:flutter_highlight/themes/atelier-estuary-light.dart';
import 'package:flutter_highlight/themes/atelier-forest-dark.dart';
import 'package:flutter_highlight/themes/atelier-forest-light.dart';
import 'package:flutter_highlight/themes/atelier-heath-dark.dart';
import 'package:flutter_highlight/themes/atelier-heath-light.dart';
import 'package:flutter_highlight/themes/atelier-lakeside-dark.dart';
import 'package:flutter_highlight/themes/atelier-lakeside-light.dart';
import 'package:flutter_highlight/themes/atelier-plateau-dark.dart';
import 'package:flutter_highlight/themes/atelier-plateau-light.dart';
import 'package:flutter_highlight/themes/atelier-savanna-dark.dart';
import 'package:flutter_highlight/themes/atelier-savanna-light.dart';
import 'package:flutter_highlight/themes/atelier-seaside-dark.dart';
import 'package:flutter_highlight/themes/atelier-seaside-light.dart';
import 'package:flutter_highlight/themes/atelier-sulphurpool-dark.dart';
import 'package:flutter_highlight/themes/atelier-sulphurpool-light.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/brown-paper.dart';
import 'package:flutter_highlight/themes/codepen-embed.dart';
import 'package:flutter_highlight/themes/color-brewer.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/dark.dart';
import 'package:flutter_highlight/themes/default.dart';
import 'package:flutter_highlight/themes/docco.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/far.dart';
import 'package:flutter_highlight/themes/foundation.dart';
import 'package:flutter_highlight/themes/github-gist.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/gml.dart';
import 'package:flutter_highlight/themes/googlecode.dart';
import 'package:flutter_highlight/themes/gradient-dark.dart';
import 'package:flutter_highlight/themes/grayscale.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
import 'package:flutter_highlight/themes/gruvbox-light.dart';
import 'package:flutter_highlight/themes/hopscotch.dart';
import 'package:flutter_highlight/themes/hybrid.dart';
import 'package:flutter_highlight/themes/idea.dart';
import 'package:flutter_highlight/themes/ir-black.dart';
import 'package:flutter_highlight/themes/isbl-editor-dark.dart';
import 'package:flutter_highlight/themes/isbl-editor-light.dart';
import 'package:flutter_highlight/themes/kimbie.dark.dart';
import 'package:flutter_highlight/themes/kimbie.light.dart';
import 'package:flutter_highlight/themes/lightfair.dart';
import 'package:flutter_highlight/themes/magula.dart';
import 'package:flutter_highlight/themes/mono-blue.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:flutter_highlight/themes/nord.dart';
import 'package:flutter_highlight/themes/obsidian.dart';
import 'package:flutter_highlight/themes/ocean.dart';
import 'package:flutter_highlight/themes/paraiso-dark.dart';
import 'package:flutter_highlight/themes/paraiso-light.dart';
import 'package:flutter_highlight/themes/pojoaque.dart';
import 'package:flutter_highlight/themes/purebasic.dart';
import 'package:flutter_highlight/themes/qtcreator_dark.dart';
import 'package:flutter_highlight/themes/qtcreator_light.dart';
import 'package:flutter_highlight/themes/railscasts.dart';
import 'package:flutter_highlight/themes/rainbow.dart';
import 'package:flutter_highlight/themes/routeros.dart';
import 'package:flutter_highlight/themes/school-book.dart';
import 'package:flutter_highlight/themes/shades-of-purple.dart';
import 'package:flutter_highlight/themes/solarized-dark.dart';
import 'package:flutter_highlight/themes/solarized-light.dart';
import 'package:flutter_highlight/themes/sunburst.dart';
import 'package:flutter_highlight/themes/tomorrow-night-blue.dart';
import 'package:flutter_highlight/themes/tomorrow-night-bright.dart';
import 'package:flutter_highlight/themes/tomorrow-night-eighties.dart';
import 'package:flutter_highlight/themes/tomorrow-night.dart';
import 'package:flutter_highlight/themes/tomorrow.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_highlight/themes/xcode.dart';
import 'package:flutter_highlight/themes/xt256.dart';
import 'package:flutter_highlight/themes/zenburn.dart';

Map<String, String> editorThemeOptions() {
  return const {
    'a11y-dark': 'A11y Dark',
    'a11y-light': 'A11y Light',
    'agate': 'Agate',
    'an-old-hope': 'An Old Hope',
    'androidstudio': 'Android Studio',
    'arduino-light': 'Arduino Light',
    'arta': 'Arta',
    'ascetic': 'Ascetic',
    'atelier-cave-dark': 'Atelier Cave Dark',
    'atelier-cave-light': 'Atelier Cave Light',
    'atelier-dune-dark': 'Atelier Dune Dark',
    'atelier-dune-light': 'Atelier Dune Light',
    'atelier-estuary-dark': 'Atelier Estuary Dark',
    'atelier-estuary-light': 'Atelier Estuary Light',
    'atelier-forest-dark': 'Atelier Forest Dark',
    'atelier-forest-light': 'Atelier Forest Light',
    'atelier-heath-dark': 'Atelier Heath Dark',
    'atelier-heath-light': 'Atelier Heath Light',
    'atelier-lakeside-dark': 'Atelier Lakeside Dark',
    'atelier-lakeside-light': 'Atelier Lakeside Light',
    'atelier-plateau-dark': 'Atelier Plateau Dark',
    'atelier-plateau-light': 'Atelier Plateau Light',
    'atelier-savanna-dark': 'Atelier Savanna Dark',
    'atelier-savanna-light': 'Atelier Savanna Light',
    'atelier-seaside-dark': 'Atelier Seaside Dark',
    'atelier-seaside-light': 'Atelier Seaside Light',
    'atelier-sulphurpool-dark': 'Atelier Sulphurpool Dark',
    'atelier-sulphurpool-light': 'Atelier Sulphurpool Light',
    'atom-one-dark': 'Atom One Dark',
    'atom-one-dark-reasonable': 'Atom One Dark Reasonable',
    'atom-one-light': 'Atom One Light',
    'brown-paper': 'Brown Paper',
    'codepen-embed': 'CodePen Embed',
    'color-brewer': 'Color Brewer',
    'darcula': 'Darcula',
    'dark': 'Dark',
    'default': 'Default',
    'docco': 'Docco',
    'dracula': 'Dracula',
    'far': 'Far',
    'foundation': 'Foundation',
    'github': 'GitHub',
    'github-gist': 'GitHub Gist',
    'gml': 'GML',
    'googlecode': 'Google Code',
    'gradient-dark': 'Gradient Dark',
    'grayscale': 'Grayscale',
    'gruvbox-dark': 'Gruvbox Dark',
    'gruvbox-light': 'Gruvbox Light',
    'hopscotch': 'Hopscotch',
    'hybrid': 'Hybrid',
    'idea': 'IDEA',
    'ir-black': 'IR Black',
    'isbl-editor-dark': 'ISBL Editor Dark',
    'isbl-editor-light': 'ISBL Editor Light',
    'kimbie.dark': 'Kimbie Dark',
    'kimbie.light': 'Kimbie Light',
    'lightfair': 'Lightfair',
    'magula': 'Magula',
    'mono-blue': 'Mono Blue',
    'monokai': 'Monokai',
    'monokai-sublime': 'Monokai Sublime',
    'night-owl': 'Night Owl',
    'nord': 'Nord',
    'obsidian': 'Obsidian',
    'ocean': 'Ocean',
    'paraiso-dark': 'Paraiso Dark',
    'paraiso-light': 'Paraiso Light',
    'pojoaque': 'Pojoaque',
    'purebasic': 'PureBasic',
    'qtcreator_dark': 'Qt Creator Dark',
    'qtcreator_light': 'Qt Creator Light',
    'railscasts': 'RailsCasts',
    'rainbow': 'Rainbow',
    'routeros': 'RouterOS',
    'school-book': 'School Book',
    'shades-of-purple': 'Shades of Purple',
    'solarized-dark': 'Solarized Dark',
    'solarized-light': 'Solarized Light',
    'sunburst': 'Sunburst',
    'tomorrow': 'Tomorrow',
    'tomorrow-night': 'Tomorrow Night',
    'tomorrow-night-blue': 'Tomorrow Night Blue',
    'tomorrow-night-bright': 'Tomorrow Night Bright',
    'tomorrow-night-eighties': 'Tomorrow Night Eighties',
    'vs': 'VS',
    'vs2015': 'VS 2015',
    'xcode': 'Xcode',
    'xt256': 'XT256',
    'zenburn': 'Zenburn',
  };
}

Map<String, TextStyle> editorThemeStyles(String themeKey) {
  switch (themeKey) {
    case 'a11y-dark':
      return a11yDarkTheme;
    case 'a11y-light':
      return a11yLightTheme;
    case 'agate':
      return agateTheme;
    case 'an-old-hope':
      return anOldHopeTheme;
    case 'androidstudio':
      return androidstudioTheme;
    case 'arduino-light':
      return arduinoLightTheme;
    case 'arta':
      return artaTheme;
    case 'ascetic':
      return asceticTheme;
    case 'atelier-cave-dark':
      return atelierCaveDarkTheme;
    case 'atelier-cave-light':
      return atelierCaveLightTheme;
    case 'atelier-dune-dark':
      return atelierDuneDarkTheme;
    case 'atelier-dune-light':
      return atelierDuneLightTheme;
    case 'atelier-estuary-dark':
      return atelierEstuaryDarkTheme;
    case 'atelier-estuary-light':
      return atelierEstuaryLightTheme;
    case 'atelier-forest-dark':
      return atelierForestDarkTheme;
    case 'atelier-forest-light':
      return atelierForestLightTheme;
    case 'atelier-heath-dark':
      return atelierHeathDarkTheme;
    case 'atelier-heath-light':
      return atelierHeathLightTheme;
    case 'atelier-lakeside-dark':
      return atelierLakesideDarkTheme;
    case 'atelier-lakeside-light':
      return atelierLakesideLightTheme;
    case 'atelier-plateau-dark':
      return atelierPlateauDarkTheme;
    case 'atelier-plateau-light':
      return atelierPlateauLightTheme;
    case 'atelier-savanna-dark':
      return atelierSavannaDarkTheme;
    case 'atelier-savanna-light':
      return atelierSavannaLightTheme;
    case 'atelier-seaside-dark':
      return atelierSeasideDarkTheme;
    case 'atelier-seaside-light':
      return atelierSeasideLightTheme;
    case 'atelier-sulphurpool-dark':
      return atelierSulphurpoolDarkTheme;
    case 'atelier-sulphurpool-light':
      return atelierSulphurpoolLightTheme;
    case 'atom-one-dark':
      return atomOneDarkTheme;
    case 'atom-one-dark-reasonable':
      return atomOneDarkReasonableTheme;
    case 'atom-one-light':
      return atomOneLightTheme;
    case 'brown-paper':
      return brownPaperTheme;
    case 'codepen-embed':
      return codepenEmbedTheme;
    case 'color-brewer':
      return colorBrewerTheme;
    case 'darcula':
      return darculaTheme;
    case 'dark':
      return darkTheme;
    case 'default':
      return defaultTheme;
    case 'docco':
      return doccoTheme;
    case 'dracula':
      return draculaTheme;
    case 'far':
      return farTheme;
    case 'foundation':
      return foundationTheme;
    case 'github':
      return githubTheme;
    case 'github-gist':
      return githubGistTheme;
    case 'gml':
      return gmlTheme;
    case 'googlecode':
      return googlecodeTheme;
    case 'gradient-dark':
      return gradientDarkTheme;
    case 'grayscale':
      return grayscaleTheme;
    case 'gruvbox-dark':
      return gruvboxDarkTheme;
    case 'gruvbox-light':
      return gruvboxLightTheme;
    case 'hopscotch':
      return hopscotchTheme;
    case 'hybrid':
      return hybridTheme;
    case 'idea':
      return ideaTheme;
    case 'ir-black':
      return irBlackTheme;
    case 'isbl-editor-dark':
      return isblEditorDarkTheme;
    case 'isbl-editor-light':
      return isblEditorLightTheme;
    case 'kimbie.dark':
      return kimbieDarkTheme;
    case 'kimbie.light':
      return kimbieLightTheme;
    case 'lightfair':
      return lightfairTheme;
    case 'magula':
      return magulaTheme;
    case 'mono-blue':
      return monoBlueTheme;
    case 'monokai':
      return monokaiTheme;
    case 'monokai-sublime':
      return monokaiSublimeTheme;
    case 'night-owl':
      return nightOwlTheme;
    case 'nord':
      return nordTheme;
    case 'obsidian':
      return obsidianTheme;
    case 'ocean':
      return oceanTheme;
    case 'paraiso-dark':
      return paraisoDarkTheme;
    case 'paraiso-light':
      return paraisoLightTheme;
    case 'pojoaque':
      return pojoaqueTheme;
    case 'purebasic':
      return purebasicTheme;
    case 'qtcreator_dark':
      return qtcreatorDarkTheme;
    case 'qtcreator_light':
      return qtcreatorLightTheme;
    case 'railscasts':
      return railscastsTheme;
    case 'rainbow':
      return rainbowTheme;
    case 'routeros':
      return routerosTheme;
    case 'school-book':
      return schoolBookTheme;
    case 'shades-of-purple':
      return shadesOfPurpleTheme;
    case 'solarized-dark':
      return solarizedDarkTheme;
    case 'solarized-light':
      return solarizedLightTheme;
    case 'sunburst':
      return sunburstTheme;
    case 'tomorrow':
      return tomorrowTheme;
    case 'tomorrow-night':
      return tomorrowNightTheme;
    case 'tomorrow-night-blue':
      return tomorrowNightBlueTheme;
    case 'tomorrow-night-bright':
      return tomorrowNightBrightTheme;
    case 'tomorrow-night-eighties':
      return tomorrowNightEightiesTheme;
    case 'vs':
      return vsTheme;
    case 'vs2015':
      return vs2015Theme;
    case 'xcode':
      return xcodeTheme;
    case 'xt256':
      return xt256Theme;
    case 'zenburn':
      return zenburnTheme;
    default:
      return draculaTheme;
  }
}
