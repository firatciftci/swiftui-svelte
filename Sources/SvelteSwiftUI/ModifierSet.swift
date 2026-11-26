struct ModifierSet: OptionSet, Hashable {
    let rawValue: UInt32

    static let framing = Self(rawValue: 1 << 0)
    static let typography = Self(rawValue: 1 << 1)
    static let appearance = Self(rawValue: 1 << 2)
    static let decorations = Self(rawValue: 1 << 3)
    static let glass = Self(rawValue: 1 << 4)
    static let transforms = Self(rawValue: 1 << 5)
    static let layers = Self(rawValue: 1 << 6)
    static let accessible = Self(rawValue: 1 << 7)
    static let lifecycle = Self(rawValue: 1 << 8)
    static let gestures = Self(rawValue: 1 << 9)
    static let measured = Self(rawValue: 1 << 10)
    static let gridCell = Self(rawValue: 1 << 11)
    static let resizing = Self(rawValue: 1 << 12)
    static let localized = Self(rawValue: 1 << 13)
    static let preferences = Self(rawValue: 1 << 14)
    static let availability = Self(rawValue: 1 << 15)
    static let animated = Self(rawValue: 1 << 16)
    static let attachments = Self(rawValue: 1 << 17)
    static let rowTraits = Self(rawValue: 1 << 18)
    static let safeArea = Self(rawValue: 1 << 19)
    static let pointer = Self(rawValue: 1 << 20)
    static let scrolling = Self(rawValue: 1 << 21)
    static let shared = Self(rawValue: 1 << 22)
    static let margins = Self(rawValue: 1 << 23)
    static let traits: Self = [.gridCell, .rowTraits]

    static let byAttribute: [String: Self] = {
        let groups: [Self: Array<String>] = [
            .framing: [
                "framealignment", "width", "height", "linebox", "minwidth", "idealwidth", "maxwidth", "minheight", "idealheight",
                "maxheight", "aspectratio", "contentmode", "padding", "fixedsize", "layoutpriority", "boxsizing", "border",
            ],
            .margins: ["margin"],
            .typography: ["font", "fontname", "fontfallbacks", "size", "design", "weight", "italic", "color", "tint", "controlsize"],
            .appearance: [
                "background", "opacity", "radius", "cornerstyle", "brightness", "colormultiply", "blendmode", "compositinggroup", "lighten",
                "insetshadow",
            ],
            .decorations: [
                "clipshape", "border", "shadow", "blur", "contentshape", "ring", "boxsizing", "radius", "cornerstyle",
            ],
            .glass: ["glasseffect", "glassid", "glassunion"],
            .transforms: ["offset", "position", "rotation", "rotationanchor", "scale", "scaleanchor"],
            .accessible: [
                "a11ychildren", "a11yhidden", "testid", "a11yheading", "a11yhint", "a11yinputlabels", "a11ylabel",
                "a11yremovetraits", "a11ysortpriority", "a11ytraits", "a11yvalue", "a11yactions",
            ],
            .lifecycle: ["taskid"],
            .gestures: ["dragdistance", "tapcount", "longpressduration"],
            .gridCell: ["cellanchor", "colspan", "columnalignment"],
            .localized: ["dir", "lang"],
            .preferences: [
                "colorscheme", "dynamictypesize", "feedbacktrigger", "preferredcolorscheme", "scrolldismisseskeyboard",
                "sensoryfeedback",
            ],
            .availability: ["disabled", "hidden", "ignoressafearea", "allowshittesting"],
            .animated: ["animated", "animation", "disablesanimations"],
            .scrolling: ["visibilitythreshold"],
            .resizing: ["container"],
            .shared: ["namespace", "matchedid"],
            .rowTraits: [
                "transition", "in", "out", "zindex", "deletedisabled", "movedisabled", "rowbackground", "rowinsets", "rowseparator",
                "rowseparatortint", "tag",
            ],
        ]
        var map: [String: Self] = [:]
        for (group, names) in groups {
            for name in names { map[name, default: []].insert(group) }
        }
        return map
    }()

    static let byEvent: [String: Self] = [
        "a11yactivate": .accessible, "a11yadjust": .accessible, "a11yescape": .accessible, "a11ymagictap": .accessible,
        "appear": .lifecycle, "disappear": .lifecycle, "task": .lifecycle,
        "longpress": .gestures, "tap": .gestures, "drag": .gestures, "magnify": .gestures, "rotate": .gestures,
        "hover": .pointer,
        "scrollvisibility": .scrolling,
        "resize": .resizing,
    ]

    static let byAttachment: [String: Self] = [
        "background": .layers, "overlay": .layers, "maskview": .decorations, "safeareainset": .safeArea,
        "searchable": .attachments, "contextmenu": .attachments, "swipeactions": .rowTraits, "toolbar": .attachments,
        "toolbarspacer": .attachments,
    ]

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init(attribute name: String, value: JSONValue) {
        self = Self.byAttribute[name] ?? []
        guard name == "listens", case let .array(types) = value else { return }
        for case let .string(type) in types { formUnion(Self.byEvent[type] ?? []) }
    }

    init(attributes: [String: JSONValue]) {
        self = []
        for (name, value) in attributes { formUnion(Self(attribute: name, value: value)) }
    }
}
