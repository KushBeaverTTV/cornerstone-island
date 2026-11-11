import QtQuick
import qs.Commons
import "../ui"
import "../lib/Ics.js" as Ics
import "../lib/Glyphs.js" as Glyphs

// The calendar: a month on the left (today filled, the chosen day ringed,
// a dot under days with events) and that day's events on the right; an
// event with a meeting link opens it. The + turns the right side into the
// list of calendars, with a field for an .ics link, a Paste button, the
// holiday country, and a ✕ on each calendar.
Item {
  id: view

  property var island: null
  readonly property var look: island.look
  readonly property var calendar: island.calendar
  readonly property var stage: island.stage
  readonly property int pad: look.s(18)
  readonly property int cell: look.s(32)

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property double chosen: today()
  property bool pickingCountry: false
  readonly property bool adding: stage.calendarAdding

  readonly property var days: calendar.month(year, month)
  readonly property var chosenEvents: days[Ics.dayKey(chosen)] || []

  // Monday or Sunday first, as the locale has it.
  readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
  readonly property int leadingBlanks: (new Date(year, month, 1).getDay() - firstWeekday + 7) % 7

  function today() {
    var t = new Date()
    return new Date(t.getFullYear(), t.getMonth(), t.getDate()).getTime()
  }

  function turnMonth(delta) {
    var d = new Date(year, month + delta, 1)
    year = d.getFullYear()
    month = d.getMonth()
  }

  function timeOf(t) {
    return Qt.formatDateTime(new Date(t), island.settings.twelveHour ? "h:mm AP" : "HH:mm")
  }

  function focusField() { Qt.callLater(function() { field.forceActiveFocus() }) }

  // Back to today each time it opens.
  onVisibleChanged: {
    if (!visible) return
    var t = new Date()
    year = t.getFullYear()
    month = t.getMonth()
    chosen = today()
    if (adding) focusField()
  }
  onAddingChanged: {
    pickingCountry = false
    if (adding && visible) focusField()
  }

  // ------------------------------------------------------------ the month
  Item {
    id: monthPane
    x: view.pad
    y: view.pad
    width: view.cell * 7
    height: parent.height - view.pad * 2

    Item {
      id: monthHeader
      width: parent.width
      height: view.look.s(26)

      Label {
        anchors.left: parent.left
        anchors.leftMargin: view.look.s(4)
        anchors.verticalCenter: parent.verticalCenter
        look: view.look
        size: 14
        weight: Font.DemiBold
        text: Qt.locale().standaloneMonthName(view.month) + " " + view.year
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        RoundButton { look: view.look; glyph: Glyphs.CHEVRON_LEFT; glyphSize: 13; onClicked: view.turnMonth(-1) }
        RoundButton { look: view.look; glyph: Glyphs.CHEVRON_RIGHT; glyphSize: 13; onClicked: view.turnMonth(1) }
      }
    }

    Row {
      id: weekdays
      y: monthHeader.height + view.look.s(6)

      Repeater {
        model: 7
        Label {
          required property int index
          width: view.cell
          horizontalAlignment: Text.AlignHCenter
          look: view.look
          size: 10
          text: Qt.locale().dayName((view.firstWeekday + index) % 7, Locale.NarrowFormat)
          color: view.look.fgDim
        }
      }
    }

    Grid {
      y: weekdays.y + weekdays.height + view.look.s(4)
      columns: 7

      Repeater {
        model: 42

        Item {
          id: day
          required property int index
          readonly property date date: new Date(view.year, view.month, 1 - view.leadingBlanks + index)
          readonly property double time: date.getTime()
          readonly property bool inMonth: date.getMonth() === view.month
          readonly property bool isToday: time === view.today()
          readonly property bool isChosen: time === view.chosen
          readonly property bool busy: !!view.days[Ics.dayKey(time)]

          width: view.cell
          height: view.look.s(26)

          Rectangle {
            anchors.centerIn: parent
            width: view.look.s(24)
            height: width
            radius: width / 2
            color: day.isToday ? view.look.accent : (dayMouse.containsMouse ? Util.alpha(view.look.fg, 0.1) : "transparent")
            border.width: day.isChosen && !day.isToday ? Math.max(1, view.look.s(1.5)) : 0
            border.color: view.look.accent
          }

          Label {
            anchors.centerIn: parent
            look: view.look
            mono: true
            size: 11
            weight: day.isToday || day.isChosen ? Font.Bold : Font.Normal
            text: String(day.date.getDate())
            color: day.isToday ? view.look.surface : view.look.fg
            opacity: day.inMonth ? 1 : 0.3
          }

          Rectangle {
            visible: day.busy
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: view.look.s(4)
            height: width
            radius: width / 2
            color: day.isToday ? view.look.fg : view.look.orange
            opacity: day.inMonth ? 1 : 0.4
          }

          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              view.chosen = day.time
              view.stage.calendarAdding = false
              if (!day.inMonth) view.turnMonth(day.date < new Date(view.year, view.month, 1) ? -1 : 1)
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------ the right side
  Item {
    id: side
    anchors.left: monthPane.right
    anchors.leftMargin: view.look.s(16)
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: view.pad
    height: parent.height - view.pad * 2

    Item {
      id: sideHeader
      width: parent.width
      height: view.look.s(26)

      Label {
        anchors.left: parent.left
        anchors.right: addButton.left
        anchors.verticalCenter: parent.verticalCenter
        look: view.look
        size: 13
        weight: Font.DemiBold
        text: view.adding ? "Calendars" : Qt.formatDate(new Date(view.chosen), "dddd d")
      }

      RoundButton {
        id: addButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        look: view.look
        glyph: view.adding ? Glyphs.CLOSE : Glyphs.PLUS
        glyphSize: 13
        onClicked: view.stage.calendarAdding = !view.stage.calendarAdding
      }
    }

    // ---- the chosen day's events
    ListView {
      visible: !view.adding
      y: sideHeader.height + view.look.s(6)
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: view.look.s(4)
      boundsBehavior: Flickable.StopAtBounds
      model: view.chosenEvents

      delegate: Rectangle {
        id: event
        required property var modelData
        readonly property bool over: !modelData.allDay && modelData.end < Date.now()
        width: ListView.view.width
        height: view.look.s(40)
        radius: view.look.s(12)
        color: Util.alpha(view.look.fg, eventMouse.containsMouse && modelData.url ? 0.1 : 0.05)
        opacity: over ? 0.5 : 1

        Rectangle {
          x: view.look.s(8)
          anchors.verticalCenter: parent.verticalCenter
          width: view.look.s(3)
          height: parent.height - view.look.s(16)
          radius: width / 2
          color: event.modelData.allDay ? view.look.orange : view.look.accent
        }

        Headline {
          x: view.look.s(18)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - view.look.s(26)
          look: view.look
          spacing: view.look.s(1)
          titleSize: 12
          detailSize: 10
          title: event.modelData.title || "Busy"
          detail: event.modelData.allDay ? "All day"
            : view.timeOf(event.modelData.start) + " – " + view.timeOf(event.modelData.end)
        }

        Label {
          visible: !!event.modelData.url
          anchors.right: parent.right
          anchors.rightMargin: view.look.s(10)
          anchors.verticalCenter: parent.verticalCenter
          look: view.look
          mono: true
          size: 12
          text: Glyphs.OPEN_LINK
          color: view.look.accent
        }

        MouseArea {
          id: eventMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: event.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (event.modelData.url) view.island.openLink(event.modelData.url)
        }
      }
    }

    Label {
      visible: !view.adding && view.chosenEvents.length === 0
      y: sideHeader.height + view.look.s(30)
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      look: view.look
      size: 12
      text: view.calendar.sources.length > 0 ? "Nothing scheduled" : "No calendar added yet.\nTap + to add one."
      color: view.look.fgDim
    }

    // How the last add went: green when it worked, red with the reason.
    Label {
      visible: !!view.calendar.lastResult
      anchors.bottom: parent.bottom
      width: parent.width
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      look: view.look
      size: 10
      weight: Font.DemiBold
      text: view.calendar.lastResult ? view.calendar.lastResult.text : ""
      color: view.calendar.lastResult && view.calendar.lastResult.ok ? view.look.green : view.look.urgent
    }

    // ---- the holiday country
    ListView {
      visible: view.adding && view.pickingCountry
      y: sideHeader.height + view.look.s(6)
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: view.look.s(2)
      boundsBehavior: Flickable.StopAtBounds
      model: [{ code: "off", name: "No holidays" }].concat(Ics.HOLIDAYS)

      delegate: Rectangle {
        id: country
        required property var modelData
        readonly property bool picked: modelData.code === "off" ? view.calendar.holidayCountry === ""
                                                                 : modelData.code === view.calendar.holidayCountry
        width: ListView.view.width
        height: view.look.s(24)
        radius: height / 2
        color: picked ? Util.alpha(view.look.accent, 0.2) : Util.alpha(view.look.fg, countryMouse.containsMouse ? 0.1 : 0.03)

        Label {
          anchors.left: parent.left
          anchors.leftMargin: view.look.s(12)
          anchors.right: parent.right
          anchors.rightMargin: view.look.s(12)
          anchors.verticalCenter: parent.verticalCenter
          look: view.look
          size: 11
          weight: country.picked ? Font.Bold : Font.Normal
          text: country.modelData.name + (country.modelData.code === view.calendar.detectedCountry ? "  (your timezone)" : "")
        }

        MouseArea {
          id: countryMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var code = country.modelData.code
            view.calendar.setHolidays(code === view.calendar.detectedCountry ? "auto" : code)
            view.pickingCountry = false
          }
        }
      }
    }

    // ---- the calendars
    Column {
      visible: view.adding && !view.pickingCountry
      y: sideHeader.height + view.look.s(6)
      width: parent.width
      spacing: view.look.s(6)

      Item {
        width: parent.width
        height: view.look.s(30)

        Chip {
          id: paste
          anchors.right: parent.right
          look: view.look
          tone: view.look.accent
          textSize: 11
          text: Glyphs.PASTE + " Paste"
          // Adds the copied link straight away, keyboard or not.
          onClicked: view.island.pasteCalendar()
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: paste.left
          anchors.rightMargin: view.look.s(6)
          height: parent.height
          radius: height / 2
          color: view.look.fgFaint
          border.width: field.activeFocus ? 1 : 0
          border.color: view.look.accent

          TextInput {
            id: field
            anchors.left: parent.left
            anchors.leftMargin: view.look.s(12)
            anchors.right: parent.right
            anchors.rightMargin: view.look.s(12)
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            font.family: view.look.mono
            font.pixelSize: view.look.f(11)
            color: view.look.fg
            selectionColor: Util.alpha(view.look.accent, 0.5)
            renderType: Text.NativeRendering
            selectByMouse: true
            maximumLength: 2048

            function commit() {
              var link = text.trim()
              if (link === "") return
              view.calendar.add(link)
              text = ""
              view.stage.calendarAdding = false
            }

            Keys.onReturnPressed: commit()
            Keys.onEnterPressed: commit()
            Keys.onEscapePressed: view.stage.calendarAdding = false

            Label {
              anchors.fill: parent
              visible: field.text === ""
              look: view.look
              mono: true
              size: 11
              text: "Calendar link (.ics)"
              color: view.look.fgDim
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            // Once focused, the field handles its own clicks and selection.
            enabled: !field.activeFocus
            onClicked: field.forceActiveFocus()
          }
        }
      }

      Rectangle {
        width: parent.width
        height: view.look.s(26)
        radius: height / 2
        color: Util.alpha(view.look.orange, holidaysMouse.containsMouse ? 0.24 : 0.14)

        Label {
          anchors.left: parent.left
          anchors.leftMargin: view.look.s(12)
          anchors.right: parent.right
          anchors.rightMargin: view.look.s(12)
          anchors.verticalCenter: parent.verticalCenter
          look: view.look
          size: 11
          weight: Font.DemiBold
          text: Glyphs.CALENDAR + "  Holidays: " + (view.calendar.holidayName || "off") + "  ›"
          color: view.look.orange
        }

        MouseArea {
          id: holidaysMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.pickingCountry = true
        }
      }

      Repeater {
        model: view.calendar.sources.filter(function(link) { return link !== view.calendar.holidayFeed })

        Rectangle {
          id: source
          required property var modelData
          readonly property string problem: {
            var st = view.calendar.statusOf(modelData)
            return st === "" || st === "ok" ? "" : (st.indexOf("HTTP ") === 0 ? st.slice(5) + " error" : st)
          }
          width: parent.width
          height: view.look.s(26)
          radius: height / 2
          color: Util.alpha(view.look.fg, 0.05)

          Label {
            anchors.left: parent.left
            anchors.leftMargin: view.look.s(12)
            anchors.right: problemText.visible ? problemText.left : remove.left
            anchors.rightMargin: view.look.s(6)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            look: view.look
            size: 10
            text: String(source.modelData).replace(/^[a-z]+:\/\//, "").replace(/\?.*$/, "")
          }

          Label {
            id: problemText
            visible: source.problem !== ""
            anchors.right: remove.left
            anchors.rightMargin: view.look.s(4)
            anchors.verticalCenter: parent.verticalCenter
            look: view.look
            size: 10
            weight: Font.DemiBold
            text: source.problem
            color: view.look.urgent
          }

          RoundButton {
            id: remove
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            look: view.look
            glyph: Glyphs.CLOSE
            glyphSize: 10
            onClicked: view.calendar.remove(source.modelData)
          }
        }
      }

      Label {
        visible: view.calendar.sources.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        maximumLineCount: 4
        lineHeight: 1.15
        look: view.look
        size: 10
        text: "Google: Settings › your calendar › Secret address in iCal format. "
          + "iCloud: share as public calendar. Outlook: Publish a calendar › ICS."
        color: view.look.fgDim
      }
    }
  }
}
