import QtQuick
import qs.Commons
import "../ui"
import "../lib/Glyphs.js" as Glyphs

// Cornerstone Jarvis expanded card: live streaming agent replies, voice &
// quick-type input, one-click handoff to full `agy` terminal, and toggles
// for hands-free "Hey Jarvis" wake-word & Piper British voice replies.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var jarvis: island.jarvis
  readonly property var stage: island.stage
  readonly property int pad: look.s(16)

  readonly property color stateTone: jarvis.listening ? look.urgent
    : (jarvis.speaking ? look.green : (jarvis.hasError ? look.urgent : look.accent))

  function focusInput() {
    Qt.callLater(function() {
      if (stage.jarvisTyping && view.visible) promptInput.forceActiveFocus()
    })
  }

  onVisibleChanged: {
    if (visible && stage.jarvisTyping) focusInput()
  }

  Connections {
    target: view.stage
    function onJarvisTypingChanged() {
      if (view.stage.jarvisTyping && view.visible) view.focusInput()
    }
  }

  // ---- Header
  Item {
    id: header
    x: view.pad
    y: view.pad - view.look.s(2)
    width: parent.width - view.pad * 2
    height: view.look.s(26)

    Label {
      id: leadIcon
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      mono: true
      size: 14
      text: view.jarvis.listening ? Glyphs.MIC : Glyphs.SPARKLE
      color: view.stateTone
    }

    Label {
      anchors.left: leadIcon.right
      anchors.leftMargin: view.look.s(7)
      anchors.right: controls.left
      anchors.rightMargin: view.look.s(8)
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      size: 12
      weight: Font.DemiBold
      text: {
        if (view.jarvis.listening) return "Listening  " + view.jarvis.elapsed
        if (view.jarvis.transcribing) return "Transcribing…"
        if (view.jarvis.thinking) return view.jarvis.statusLine || "Thinking…"
        if (view.jarvis.speaking) return "Speaking…"
        if (view.jarvis.hasError) return "Jarvis · error"
        return view.jarvis.turnCount > 0 ? "Jarvis · thread (" + view.jarvis.turnCount + ")" : "Jarvis"
      }
      color: view.look.fg
    }

    Row {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: view.look.s(5)

      // Hands-free "Hey Jarvis" wake-word toggle pill
      Rectangle {
        height: view.look.s(22)
        width: wakeLabel.implicitWidth + view.look.s(14)
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        readonly property color chipTone: !view.jarvis.wakeEnabled ? view.look.fgDim
          : (view.jarvis.wakeGated ? view.look.orange : view.look.green)
        color: Util.alpha(chipTone, wakeMouse.containsMouse ? 0.24 : 0.14)

        Label {
          id: wakeLabel
          anchors.centerIn: parent
          look: view.look
          size: 10
          weight: Font.DemiBold
          text: !view.jarvis.wakeEnabled ? (Glyphs.MIC_OFF + " Wake off")
            : (view.jarvis.wakeGated ? (Glyphs.MIC + " Call paused") : (Glyphs.MIC + " Hey Jarvis"))
          color: parent.chipTone
        }

        MouseArea {
          id: wakeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.jarvis.toggleWake()
        }
      }

      // Spoken TTS toggle
      RoundButton {
        look: view.look
        glyphSize: 12
        glyph: view.jarvis.ttsEnabled ? Glyphs.SPEAKER : "\u{f075f}"
        color: view.jarvis.ttsEnabled ? view.look.accent : view.look.fgDim
        onClicked: view.jarvis.toggleTts()
      }

      RoundButton {
        look: view.look
        glyphSize: 11
        glyph: Glyphs.CLOSE
        onClicked: view.stage.collapse()
      }
    }
  }

  // ---- Conversation Body
  Rectangle {
    id: transcriptBox
    x: view.pad
    y: header.y + header.height + view.look.s(8)
    width: parent.width - view.pad * 2
    height: inputRow.y - y - view.look.s(8)
    radius: view.look.s(14)
    color: Util.alpha(view.look.fg, 0.05)
    clip: true

    Flickable {
      id: scroller
      anchors.fill: parent
      anchors.margins: view.look.s(10)
      contentWidth: width
      contentHeight: msgCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: msgCol
        width: scroller.width
        spacing: view.look.s(5)

        Label {
          visible: view.jarvis.prompt !== ""
          width: parent.width
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          look: view.look
          size: 10
          text: "You: " + view.jarvis.prompt
          color: view.look.fgDim
        }

        Label {
          visible: view.jarvis.hasError
          width: parent.width
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          maximumLineCount: 10
          look: view.look
          size: 11
          text: view.jarvis.error
          color: view.look.urgent
        }

        Label {
          width: parent.width
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          maximumLineCount: 200
          lineHeight: 1.24
          look: view.look
          size: 12
          text: {
            if (view.jarvis.reply !== "") return view.jarvis.reply
            if (view.jarvis.listening) return "Speak now — pauses automatically when you finish, or click Stop."
            if (view.jarvis.transcribing) return "Transcribing with local Qwen3-ASR…"
            if (view.jarvis.thinking) return "Asking agy…"
            return 'Say "Hey Jarvis", click the mic orb, or type below to talk to agy.'
          }
          color: view.jarvis.reply !== "" ? view.look.fg : view.look.fgDim
        }
      }
    }
  }

  // ---- Quick-Type Input Row
  Item {
    id: inputRow
    x: view.pad
    y: footer.y - height - view.look.s(8)
    width: parent.width - view.pad * 2
    height: view.look.s(30)

    Chip {
      id: sendBtn
      anchors.right: parent.right
      look: view.look
      tone: view.look.accent
      textSize: 11
      text: "Send"
      onClicked: promptInput.submit()
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: sendBtn.left
      anchors.rightMargin: view.look.s(6)
      height: parent.height
      radius: height / 2
      color: view.look.fgFaint
      border.width: promptInput.activeFocus ? 1 : 0
      border.color: view.look.accent

      TextInput {
        id: promptInput
        anchors.left: parent.left
        anchors.leftMargin: view.look.s(12)
        anchors.right: parent.right
        anchors.rightMargin: view.look.s(12)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        font.family: view.look.sans
        font.pixelSize: view.look.f(11)
        color: view.look.fg
        selectionColor: Util.alpha(view.look.accent, 0.5)
        renderType: Text.NativeRendering
        selectByMouse: true
        maximumLength: 2048

        onActiveFocusChanged: {
          if (activeFocus) view.stage.jarvisTyping = true
        }

        function submit() {
          var q = text.trim()
          if (q === "") return
          text = ""
          view.stage.jarvisTyping = false
          view.jarvis.ask(q)
        }

        Keys.onReturnPressed: submit()
        Keys.onEnterPressed: submit()
        Keys.onEscapePressed: {
          view.stage.jarvisTyping = false
          view.stage.collapse()
        }

        Label {
          anchors.fill: parent
          visible: promptInput.text === ""
          look: view.look
          size: 11
          text: "Ask Jarvis anything… (Enter to send)"
          color: view.look.fgDim
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        enabled: !promptInput.activeFocus
        onClicked: {
          view.stage.jarvisTyping = true
          promptInput.forceActiveFocus()
        }
      }
    }
  }

  // ---- Footer Actions
  Item {
    id: footer
    x: view.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.pad - view.look.s(2)
    width: parent.width - view.pad * 2
    height: view.look.s(26)

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: view.look.s(6)

      Chip {
        look: view.look
        tone: view.jarvis.busy ? view.look.urgent : view.look.accent
        textSize: 11
        text: view.jarvis.listening ? (Glyphs.STOP + "  Send voice")
          : (view.jarvis.busy ? (Glyphs.STOP + "  Stop")
          : (view.jarvis.turnCount > 0 ? (Glyphs.MIC + "  Follow up") : (Glyphs.MIC + "  Talk")))
        onClicked: {
          if (view.jarvis.listening) view.jarvis.listen()
          else if (view.jarvis.busy) view.jarvis.stop()
          else view.jarvis.listen()
        }
      }

      Chip {
        look: view.look
        tone: view.look.fg
        textSize: 11
        text: Glyphs.OPEN_LINK + "  Open in agy"
        onClicked: view.jarvis.popOut()
      }
    }

    Chip {
      visible: view.jarvis.turnCount > 0 || view.jarvis.reply !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      look: view.look
      tone: view.look.fgDim
      textSize: 11
      text: "New thread"
      onClicked: view.jarvis.reset()
    }
  }
}
