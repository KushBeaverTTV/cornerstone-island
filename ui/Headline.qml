import QtQuick

// A title over a dimmer second line, both cut short when too long: the text
// block of cards, banners and opened activities.
Column {
  id: headline

  property var look: null
  property string title: ""
  property string detail: ""
  property real titleSize: 14
  property real detailSize: 12
  property color titleColor: look ? look.fg : "white"
  property color detailColor: look ? look.fgDim : "white"

  spacing: look ? look.s(2) : 2

  Label {
    width: parent.width
    look: headline.look
    size: headline.titleSize
    weight: Font.DemiBold
    text: headline.title
    color: headline.titleColor
  }

  Label {
    width: parent.width
    visible: text !== ""
    look: headline.look
    size: headline.detailSize
    text: headline.detail
    color: headline.detailColor
  }
}
