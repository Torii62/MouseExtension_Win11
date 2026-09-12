; MouseGestureL.ahk 1.41 用プラグイン / Phase 1 共通基盤
; AutoHotkey v1.1.37.02 Unicode を対象とする。
;
; このファイルを単体で実行して動作確認しないこと。MouseGestureL から読み込む。

ME_Product := ME_CreateProductInfo()
ME_Defaults := ME_CreateDefaults()
ME_Config := {}
ME_Services := ME_CreateCommonServices()
ME_State := ME_CreateRuntimeState()
ME_Initialize()


; -----------------------------------------------------------------------------
; 起動と製品情報
; -----------------------------------------------------------------------------

ME_CreateProductInfo() {
    ; 製品固有値は将来の改名・版更新に備えてここだけに集約する。
    product := {}
    product.Name := "MouseExtension_Win11"
    product.Version := "1.1.1"
    product.AhkFileName := "MouseExtension_Win11.ahk"
    product.IniFileName := "MouseExtension_Win11.ini"

    sourceFile := A_LineFile
    SplitPath, sourceFile, , sourceDir
    product.ScriptDirectory := sourceDir
    product.ScriptPath := sourceDir . "\" . product.AhkFileName
    product.IniPath := sourceDir . "\" . product.IniFileName
    return product
}

ME_Initialize() {
    global ME_Product, ME_Defaults, ME_Config, ME_State

    if (ME_State.Initialized)
        return true

    ; OnExit は共通Cleanupへ一本化する。関数形式はAHK v1.1.20+の仕様。
    OnExit(Func("MouseExtension_OnExit"))
    ME_State.ExitHandlerRegistered := true

    iniReady := ME_EnsureIni(ME_Product.IniPath, ME_Defaults)
    if (FileExist(ME_Product.IniPath))
        ME_Config := ME_LoadConfig(ME_Product.IniPath, ME_Defaults)
    else
        ; INIを利用できなくてもプラグイン全体は終了させず、既定値で閉じる。
        ME_Config := ME_LoadConfig("", ME_Defaults)
    ME_State.Initialized := true
    ME_InitializeNative()
    ME_InitializeAlwaysOnTop()
    ME_InitializeOpenExeFolder()
    ME_InitializeMoveDisabledWindow()
    ME_InitializeVolumeOverlay()
    ME_InitializeTaskbar()
    ME_InitializeTrayWheelVolume()
    ME_InitializeTrayMiddleClickMute()
    ME_InitializeTabSwitch()
    ME_InitializeExplorerViewMode()
    ME_InitializeSpecialScrollbarScroll()
    ME_InitializeBrowserDragScroll()
    ME_InitializeAccelScroll()
    ME_Debug("Initialization completed.")
    return iniReady
}


; -----------------------------------------------------------------------------
; INIスキーマ、初回生成、不足キー補完
; -----------------------------------------------------------------------------

ME_CreateDefaults() {
    defaults := {Sections: [], Lookup: {}}

    ME_AddDefaultSection(defaults, "EnableFunction")
    ME_AddDefaultKey(defaults, "EnableFunction", "AlwaysOnTop", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "OpenExeFolder", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "MoveDisabledWindow", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "TabSwitch", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "ExplorerViewMode", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "Taskbar", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "AccelScroll", "0")
    ME_AddDefaultKey(defaults, "EnableFunction", "SpecialScrollbarScroll", "1")
    ME_AddDefaultKey(defaults, "EnableFunction", "BrowserDragScroll", "1")

    ME_AddDefaultSection(defaults, "General")
    ME_AddDefaultKey(defaults, "General", "Debug", "0")

    ME_AddDefaultSection(defaults, "AlwaysOnTop")
    ME_AddDefaultKey(defaults, "AlwaysOnTop", "FrameColor", "0078D4")
    ME_AddDefaultKey(defaults, "AlwaysOnTop", "FrameThickness", "3")

    ME_AddDefaultSection(defaults, "TabSwitch")
    ME_AddDefaultKey(defaults, "TabSwitch", "Firefox", "1")
    ME_AddDefaultKey(defaults, "TabSwitch", "Chrome", "1")
    ME_AddDefaultKey(defaults, "TabSwitch", "Edge", "1")
    ME_AddDefaultKey(defaults, "TabSwitch", "Notepad", "1")
    ME_AddDefaultKey(defaults, "TabSwitch", "Explorer", "1")
    ME_AddDefaultKey(defaults, "TabSwitch", "SysTabControl32", "1")

    ME_AddDefaultSection(defaults, "BrowserDragScroll")
    ME_AddDefaultKey(defaults, "BrowserDragScroll", "Firefox", "1")
    ME_AddDefaultKey(defaults, "BrowserDragScroll", "Chrome", "1")
    ME_AddDefaultKey(defaults, "BrowserDragScroll", "Edge", "1")
    ME_AddDefaultKey(defaults, "BrowserDragScroll", "Explorer", "1")

    ME_AddDefaultSection(defaults, "AccelScroll")
    ME_AddDefaultKey(defaults, "AccelScroll", "MinThrottle", "2")
    ME_AddDefaultKey(defaults, "AccelScroll", "MaxThrottle", "10")
    ME_AddDefaultKey(defaults, "AccelScroll", "MinWheelSpeed", "8")
    ME_AddDefaultKey(defaults, "AccelScroll", "MaxWheelSpeed", "25")
    ME_AddDefaultKey(defaults, "AccelScroll", "ExcludeExe", "")

    ME_AddDefaultSection(defaults, "Taskbar")
    ME_AddDefaultKey(defaults, "Taskbar", "StartWheel", "1")
    ME_AddDefaultKey(defaults, "Taskbar", "TaskButtonWheel", "1")
    ME_AddDefaultKey(defaults, "Taskbar", "TaskButtonWheelMultiWindow", "1")
    ME_AddDefaultKey(defaults, "Taskbar", "TaskButtonMiddleClick", "0")
    ME_AddDefaultKey(defaults, "Taskbar", "TaskButtonMiddleClickMultiWindow", "0")
    ME_AddDefaultKey(defaults, "Taskbar", "TrayWheelVolume", "1")
    ME_AddDefaultKey(defaults, "Taskbar", "TrayMiddleClickMute", "1")

    ME_AddDefaultSection(defaults, "Volume")
    ME_AddDefaultKey(defaults, "Volume", "Step", "1")
    ME_AddDefaultKey(defaults, "Volume", "AccelStrength", "3")

    ME_AddDefaultSection(defaults, "VolumeOverlay")
    ME_AddDefaultKey(defaults, "VolumeOverlay", "Enabled", "1")
    ME_AddDefaultKey(defaults, "VolumeOverlay", "DurationMs", "2000")
    ME_AddDefaultKey(defaults, "VolumeOverlay", "MainColor", "444444")

    ME_AddDefaultSection(defaults, "SpecialScrollbarScroll")
    ME_AddDefaultKey(defaults, "SpecialScrollbarScroll", "Vertical", "-1")
    ME_AddDefaultKey(defaults, "SpecialScrollbarScroll", "Horizontal", "-1")

    ; TabSpecial / TabIgnore はキーが可変なので固定スキーマには含めない。
    defaults.RuleSections := ["TabSpecial", "TabIgnore"]
    return defaults
}

ME_AddDefaultSection(ByRef defaults, sectionName) {
    section := {Name: sectionName, Keys: []}
    defaults.Sections.Push(section)
    defaults.Lookup[sectionName] := {}
}

ME_AddDefaultKey(ByRef defaults, sectionName, keyName, defaultValue) {
    for _, section in defaults.Sections {
        if (section.Name = sectionName) {
            section.Keys.Push({Name: keyName, Value: defaultValue})
            defaults.Lookup[sectionName][keyName] := defaultValue
            return
        }
    }
}

ME_GetDefault(defaults, sectionName, keyName) {
    return defaults.Lookup[sectionName][keyName]
}

ME_EnsureIni(iniPath, defaults) {
    if (!FileExist(iniPath))
        return ME_CreateInitialIni(iniPath, defaults)
    return ME_CompleteMissingIniEntries(iniPath, defaults)
}

ME_CreateInitialIni(iniPath, defaults) {
    if (FileExist(iniPath))
        return true

    text := ME_BuildInitialIniText(defaults)
    file := FileOpen(iniPath, "w", "UTF-8")
    if (!IsObject(file))
        return false

    written := file.Write(text)
    file.Close()
    return (written >= StrLen(text))
}

ME_BuildInitialIniText(defaults) {
    global ME_Product
    text := "; " . ME_Product.Name . " 設定ファイル`r`n"
    text .= "; 0=OFF / 1=ON です。`r`n"
    text .= "; 設定変更は MouseGestureL / プラグインの再読み込み後に反映されます。`r`n"
    text .= "; 不正値は実行時だけ既定値へフォールバックし、このファイルを自動修正しません。`r`n"
    text .= "; SpecialScrollbarScroll: 0=無効 / 1～10=line / -1=page / -2=edge。`r`n`r`n"

    for _, section in defaults.Sections {
        text .= "[" . section.Name . "]`r`n"
        for _, key in section.Keys
            text .= key.Name . "=" . key.Value . "`r`n"
        text .= "`r`n"
    }

    text .= "[TabSpecial]`r`n"
    text .= "; 形式: Class|Title|Left|Top|Width|Height`r`n"
    text .= "; Class は完全一致、Title は部分一致。一方が空ならその条件を使いません。`r`n"
    text .= "; 例:`r`n"
    text .= "; Rule1=bosa_sdm_XL9||15|31|851|39`r`n`r`n"
    text .= "[TabIgnore]`r`n"
    text .= "; 形式: Class|Title`r`n"
    text .= "; Class は完全一致、Title は部分一致。一方が空ならその条件を使いません。`r`n"
    text .= "; 例:`r`n"
    text .= "; Rule1=SomeWindowClass|Options`r`n"
    return text
}

ME_CompleteMissingIniEntries(iniPath, defaults) {
    inventory := ME_ReadIniInventory(iniPath)
    if (!IsObject(inventory))
        return false

    succeeded := true
    missingDefaultSections := []
    for _, section in defaults.Sections {
        sectionId := ME_Lower(section.Name)
        if (!inventory.Sections.HasKey(sectionId)) {
            missingDefaultSections.Push(section)
            continue
        }
        for _, key in section.Keys {
            keyId := sectionId . Chr(30) . ME_Lower(key.Name)
            if (!inventory.Keys.HasKey(keyId)) {
                IniWrite, % key.Value, %iniPath%, % section.Name, % key.Name
                if (ErrorLevel)
                    succeeded := false
            }
        }
    }
    if (missingDefaultSections.MaxIndex()
        && !ME_AppendMissingDefaultSections(iniPath, missingDefaultSections))
        succeeded := false

    missingRuleSections := []
    for _, sectionName in defaults.RuleSections {
        if (!inventory.Sections.HasKey(ME_Lower(sectionName)))
            missingRuleSections.Push(sectionName)
    }
    if (missingRuleSections.MaxIndex() && !ME_AppendMissingRuleSections(iniPath, missingRuleSections))
        succeeded := false

    return succeeded
}

ME_ReadIniInventory(iniPath) {
    FileRead, iniText, %iniPath%
    if (ErrorLevel)
        return false

    inventory := {Sections: {}, Keys: {}}
    currentSection := ""
    Loop, Parse, iniText, `n, `r
    {
        line := Trim(A_LoopField)
        if (RegExMatch(line, "^\[([^\]]+)\][ \t]*(?:[;#].*)?$", match)) {
            currentSection := ME_Lower(Trim(match1))
            inventory.Sections[currentSection] := true
            continue
        }
        if (currentSection = "" || line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue

        equalsPos := InStr(line, "=")
        if (!equalsPos)
            continue
        keyName := ME_Lower(Trim(SubStr(line, 1, equalsPos - 1)))
        if (keyName != "")
            inventory.Keys[currentSection . Chr(30) . keyName] := true
    }
    return inventory
}

ME_AppendMissingDefaultSections(iniPath, sections) {
    reader := FileOpen(iniPath, "r")
    if (!IsObject(reader))
        return false
    iniEncoding := reader.Encoding
    iniText := reader.Read()
    reader.Close()

    lineEndingView := StrReplace(iniText, "`r`n", "`n")
    lineEndingView := StrReplace(lineEndingView, "`r", "`n")
    if (lineEndingView = "")
        separator := ""
    else if (RegExMatch(lineEndingView, "\n[ \t]*\n$"))
        separator := ""
    else if (SubStr(lineEndingView, 0) == "`n")
        separator := "`r`n"
    else
        separator := "`r`n`r`n"

    text := separator
    for index, section in sections {
        if (index > 1)
            text .= "`r`n"
        text .= "[" . section.Name . "]`r`n"
        for _, key in section.Keys
            text .= key.Name . "=" . key.Value . "`r`n"
    }

    file := FileOpen(iniPath, "a", iniEncoding)
    if (!IsObject(file))
        return false
    written := file.Write(text)
    file.Close()
    return (written >= StrLen(text))
}

ME_AppendMissingRuleSections(iniPath, sectionNames) {
    ; 既存BOMを読んで同じ文字コードで追記し、ユーザーのINIを混在encodingにしない。
    reader := FileOpen(iniPath, "r")
    if (!IsObject(reader))
        return false
    iniEncoding := reader.Encoding
    reader.Close()

    file := FileOpen(iniPath, "a", iniEncoding)
    if (!IsObject(file))
        return false

    text := "`r`n"
    for _, sectionName in sectionNames {
        if (sectionName = "TabSpecial") {
            text .= "[TabSpecial]`r`n"
            text .= "; 形式: Class|Title|Left|Top|Width|Height`r`n"
            text .= "; 例: Rule1=bosa_sdm_XL9||15|31|851|39`r`n`r`n"
        } else if (sectionName = "TabIgnore") {
            text .= "[TabIgnore]`r`n"
            text .= "; 形式: Class|Title`r`n"
            text .= "; 例: Rule1=SomeWindowClass|Options`r`n`r`n"
        }
    }
    written := file.Write(text)
    file.Close()
    return (written >= StrLen(text))
}


; -----------------------------------------------------------------------------
; INI読込と検証済みConfig
; -----------------------------------------------------------------------------

ME_LoadConfig(iniPath, defaults) {
    config := {}
    config.EnableFunction := {}
    for _, keyName in ["AlwaysOnTop", "OpenExeFolder", "MoveDisabledWindow"
        , "TabSwitch", "ExplorerViewMode", "Taskbar", "AccelScroll"
        , "SpecialScrollbarScroll", "BrowserDragScroll"]
        config.EnableFunction[keyName] := ME_ReadOnOff(iniPath, defaults, "EnableFunction", keyName)

    config.General := {}
    config.General.Debug := ME_ReadOnOff(iniPath, defaults, "General", "Debug")

    config.AlwaysOnTop := {}
    config.AlwaysOnTop.FrameColor := ME_ReadColor(iniPath, defaults, "AlwaysOnTop", "FrameColor")
    config.AlwaysOnTop.FrameThickness := ME_ReadInteger(iniPath, defaults, "AlwaysOnTop", "FrameThickness", 1, 10)

    config.TabSwitch := {}
    for _, keyName in ["Firefox", "Chrome", "Edge", "Notepad", "Explorer", "SysTabControl32"]
        config.TabSwitch[keyName] := ME_ReadOnOff(iniPath, defaults, "TabSwitch", keyName)

    config.BrowserDragScroll := {}
    for _, keyName in ["Firefox", "Chrome", "Edge", "Explorer"]
        config.BrowserDragScroll[keyName] := ME_ReadOnOff(iniPath, defaults
            , "BrowserDragScroll", keyName)

    config.AccelScroll := {}
    throttlePair := ME_ReadAccelScrollPair(iniPath, defaults, "MinThrottle"
        , "MaxThrottle", 1, 16, false, 2, 10)
    config.AccelScroll.MinThrottle := throttlePair.Minimum
    config.AccelScroll.MaxThrottle := throttlePair.Maximum
    wheelSpeedPair := ME_ReadAccelScrollPair(iniPath, defaults, "MinWheelSpeed"
        , "MaxWheelSpeed", 1, 100, true, 8, 25)
    config.AccelScroll.MinWheelSpeed := wheelSpeedPair.Minimum
    config.AccelScroll.MaxWheelSpeed := wheelSpeedPair.Maximum
    excludeRaw := ME_ReadIniValue(iniPath, "AccelScroll", "ExcludeExe", ME_GetDefault(defaults, "AccelScroll", "ExcludeExe"))
    config.AccelScroll.ExcludeExe := ME_ParseExecutableList(excludeRaw)

    config.Taskbar := {}
    for _, keyName in ["StartWheel", "TaskButtonWheel", "TaskButtonWheelMultiWindow"
        , "TaskButtonMiddleClick", "TrayWheelVolume", "TrayMiddleClickMute"]
        config.Taskbar[keyName] := ME_ReadOnOff(iniPath, defaults, "Taskbar", keyName)
    config.Taskbar.TaskButtonMiddleClickMultiWindow := ME_ReadInteger(iniPath, defaults
        , "Taskbar", "TaskButtonMiddleClickMultiWindow", 0, 2)

    config.Volume := {}
    config.Volume.Step := ME_ReadInteger(iniPath, defaults, "Volume", "Step", 1, 10)
    config.Volume.AccelStrength := ME_ReadInteger(iniPath, defaults, "Volume", "AccelStrength", 1, 5)

    config.VolumeOverlay := {}
    config.VolumeOverlay.Enabled := ME_ReadOnOff(iniPath, defaults, "VolumeOverlay", "Enabled")
    config.VolumeOverlay.DurationMs := ME_ReadInteger(iniPath, defaults, "VolumeOverlay", "DurationMs", 250, 10000)
    config.VolumeOverlay.MainColor := ME_ReadColor(iniPath, defaults, "VolumeOverlay", "MainColor")

    config.SpecialScrollbarScroll := {}
    config.SpecialScrollbarScroll.Vertical := ME_ReadSpecialScrollbarScrollValue(iniPath
        , defaults, "Vertical")
    config.SpecialScrollbarScroll.Horizontal := ME_ReadSpecialScrollbarScrollValue(iniPath
        , defaults, "Horizontal")

    config.TabSpecial := ME_ReadRuleSection(iniPath, "TabSpecial", "ME_ParseTabSpecialRule")
    config.TabIgnore := ME_ReadRuleSection(iniPath, "TabIgnore", "ME_ParseTabIgnoreRule")
    return config
}

ME_ReadIniValue(iniPath, sectionName, keyName, defaultValue) {
    if (iniPath = "")
        return Trim(defaultValue)
    missing := "{ME_MISSING_7D79B383_9138_48DE_A4F0_958F8A7B5E7E}"
    IniRead, value, %iniPath%, %sectionName%, %keyName%, %missing%
    if (value = missing)
        value := defaultValue
    return Trim(value)
}

ME_ReadOnOff(iniPath, defaults, sectionName, keyName) {
    defaultValue := ME_GetDefault(defaults, sectionName, keyName)
    value := ME_ReadIniValue(iniPath, sectionName, keyName, defaultValue)
    if (StrLen(value) = 1 && (value == "0" || value == "1"))
        return value + 0
    return defaultValue + 0
}

ME_ReadInteger(iniPath, defaults, sectionName, keyName, minimum, maximum) {
    defaultValue := ME_GetDefault(defaults, sectionName, keyName)
    value := ME_ReadIniValue(iniPath, sectionName, keyName, defaultValue)
    if (!ME_IsIntegerString(value))
        return defaultValue + 0
    number := value + 0
    if (number < minimum || number > maximum)
        return defaultValue + 0
    return number
}

ME_ReadAccelScrollPair(iniPath, defaults, minimumKey, maximumKey
    , allowedMinimum, allowedMaximum, requireStrictIncrease
    , safetyMinimum, safetyMaximum) {
    rawMinimum := ME_ReadIniValue(iniPath, "AccelScroll", minimumKey
        , ME_GetDefault(defaults, "AccelScroll", minimumKey))
    rawMaximum := ME_ReadIniValue(iniPath, "AccelScroll", maximumKey
        , ME_GetDefault(defaults, "AccelScroll", maximumKey))
    if (!ME_IsIntegerString(rawMinimum) || !ME_IsIntegerString(rawMaximum))
        return {Minimum: safetyMinimum, Maximum: safetyMaximum}

    minimumValue := rawMinimum + 0
    maximumValue := rawMaximum + 0
    if (requireStrictIncrease)
        relationInvalid := (minimumValue >= maximumValue)
    else
        relationInvalid := (minimumValue > maximumValue)
    if (minimumValue < allowedMinimum || minimumValue > allowedMaximum
        || maximumValue < allowedMinimum || maximumValue > allowedMaximum
        || relationInvalid)
        return {Minimum: safetyMinimum, Maximum: safetyMaximum}
    return {Minimum: minimumValue, Maximum: maximumValue}
}

ME_ReadSpecialScrollbarScrollValue(iniPath, defaults, keyName) {
    defaultValue := ME_GetDefault(defaults, "SpecialScrollbarScroll", keyName)
    value := ME_ReadIniValue(iniPath, "SpecialScrollbarScroll", keyName, defaultValue)
    if (!ME_IsIntegerString(value))
        return defaultValue + 0
    number := value + 0
    if (number = -2 || number = -1 || (number >= 0 && number <= 10))
        return number
    return defaultValue + 0
}

ME_ReadColor(iniPath, defaults, sectionName, keyName) {
    defaultValue := ME_GetDefault(defaults, sectionName, keyName)
    value := ME_ReadIniValue(iniPath, sectionName, keyName, defaultValue)
    if (!RegExMatch(value, "i)^[0-9a-f]{6}$"))
        value := defaultValue
    StringUpper, value, value
    return value
}

ME_IsIntegerString(value) {
    return RegExMatch(value, "^-?[0-9]+$")
}

ME_ParseExecutableList(rawValue) {
    result := {List: [], Lookup: {}}
    for _, item in StrSplit(rawValue, ",") {
        item := Trim(item)
        if (item = "")
            continue
        ; フルパス、ディレクトリ、ドライブ指定は受け付けず、.exe名だけ許可する。
        if (InStr(item, "\") || InStr(item, "/") || InStr(item, ":"))
            continue
        if (!RegExMatch(item, "i)^.+\.exe$"))
            continue
        normalized := ME_Lower(item)
        if (!result.Lookup.HasKey(normalized)) {
            result.List.Push(normalized)
            result.Lookup[normalized] := true
        }
    }
    return result
}

ME_ReadRuleSection(iniPath, sectionName, parserName) {
    rules := []
    if (iniPath = "")
        return rules

    IniRead, sectionText, %iniPath%, %sectionName%
    if (ErrorLevel || sectionText = "ERROR")
        return rules

    parser := Func(parserName)
    Loop, Parse, sectionText, `n, `r
    {
        line := A_LoopField
        equalsPos := InStr(line, "=")
        if (!equalsPos)
            continue
        keyName := Trim(SubStr(line, 1, equalsPos - 1))
        ruleText := Trim(SubStr(line, equalsPos + 1))
        if (!RegExMatch(keyName, "i)^Rule([1-9][0-9]*)$", match))
            continue

        rule := parser.Call(ruleText)
        if (!IsObject(rule))
            continue
        rule.Number := match1 + 0
        ME_InsertRuleSorted(rules, rule)
    }
    return rules
}

ME_ParseTabSpecialRule(ruleText) {
    fields := StrSplit(ruleText, "|")
    if (fields.MaxIndex() != 6)
        return false

    className := Trim(fields[1])
    titleText := Trim(fields[2])
    left := Trim(fields[3])
    top := Trim(fields[4])
    width := Trim(fields[5])
    height := Trim(fields[6])
    if (className = "" && titleText = "")
        return false
    if (!ME_IsIntegerString(left) || !ME_IsIntegerString(top)
        || !ME_IsIntegerString(width) || !ME_IsIntegerString(height))
        return false
    if ((width + 0) <= 0 || (height + 0) <= 0)
        return false

    return {Class: className, Title: titleText, Left: left + 0, Top: top + 0
        , Width: width + 0, Height: height + 0}
}

ME_ParseTabIgnoreRule(ruleText) {
    fields := StrSplit(ruleText, "|")
    if (fields.MaxIndex() != 2)
        return false
    className := Trim(fields[1])
    titleText := Trim(fields[2])
    if (className = "" && titleText = "")
        return false
    return {Class: className, Title: titleText}
}

ME_InsertRuleSorted(ByRef rules, rule) {
    insertAt := rules.MaxIndex() ? rules.MaxIndex() + 1 : 1
    for index, existing in rules {
        if (rule.Number < existing.Number) {
            insertAt := index
            break
        }
    }
    rules.InsertAt(insertAt, rule)
}

ME_Lower(value) {
    StringLower, lowered, value
    return lowered
}


; -----------------------------------------------------------------------------
; Common Services / Runtime State
; -----------------------------------------------------------------------------

ME_CreateCommonServices() {
    services := {}
    services.UIA := {Initialization: {State: "NotAttempted", FailureCount: 0
            , LastFailureTick: 0}
        , AutomationPtr: 0, RawViewWalkerPtr: 0
        , HitTestCache: {Valid: false, X: 0, Y: 0, Hwnd: 0
            , ElementPtr: 0, Tick: 0, DurationMs: 50}}
    services.HitTest := {Valid: false, X: 0, Y: 0, Hwnd: 0
        , Tick: 0, DurationMs: 30, Result: false}
    return services
}

ME_CreateRuntimeState() {
    state := {Initialized: false, ExitHandlerRegistered: false
        , AcceptingInput: true, CleanupStarted: false
        , SyntheticInputDepth: 0, Timers: []}
    state.Native := {Initialized: false, Available: false, Module: 0, Path: ""
        , LastLoadError: 0, AppIdProcAddress: 0, VirtualDesktopProcAddress: 0}
    state.AlwaysOnTop := {Initialized: false, CleanupStarted: false
        , HotkeyName: "~$+LButton", HotkeyCallback: false, HotkeyRegistered: false
        , ExplorerFallbackBusy: false
        , TimerCallback: false, TimerRegistered: false, TimerRunning: false
        , TimerIntervalMs: 100, MoveSizeTimerIntervalMs: 16, ActiveTimerIntervalMs: 0
        , ManagedWindows: {}, FrameWindows: {}, MoveSizeWindows: {}
        , WinEventCallbackPtr: 0, WinEventHooks: [], WinEventHooksInstalled: false
        , IdentityPropertyName: "", NextIdentityToken: 1, NextFrameSerial: 1}
    state.OpenExeFolder := {Initialized: false, CleanupStarted: false
        , HotkeyName: "~$^LButton", HotkeyCallback: false, HotkeyRegistered: false
        , Pending: false, PendingTimerCallback: false, PendingTimerRegistered: false
        , PendingTimerRunning: false, PendingTimerIntervalMs: 15
        , ForegroundPending: false, ForegroundTimerCallback: false
        , ForegroundTimerRegistered: false, ForegroundTimerRunning: false
        , ForegroundTimerIntervalMs: 50, ForegroundTimeoutMs: 750}
    state.MoveDisabledWindow := {Initialized: false, CleanupStarted: false
        , HotkeyName: "~$LButton", HotkeyCallback: false, HotkeyRegistered: false
        , TimerCallback: false, TimerRegistered: false, TimerRunning: false
        , TimerIntervalMs: 10, Drag: false}
    state.TabSwitch := {Initialized: false, CleanupStarted: false, Candidate: false
        , CandidateLifetimeMs: 100, AncestryMaxDepth: 11
        , NotepadAncestryMaxDepth: 13, ExplorerAncestryMaxDepth: 13
        , SysTabAncestryMaxDepth: 8}
    state.ExplorerViewMode := {Initialized: false, CleanupStarted: false
        , Candidate: false, CandidateLifetimeMs: 100, ProbeBusy: false}
    state.SpecialScrollbarScroll := {Initialized: false, CleanupStarted: false
        , Candidate: false, CandidateLifetimeMs: 100
        , ScrollBarMaxDepth: 3, ContainerMaxDepth: 6}
    state.BrowserDragScroll := {Initialized: false, CleanupStarted: false
        , Candidate: false, CandidateLifetimeMs: 100}
    state.AccelScroll := {Initialized: false, CleanupStarted: false
        , LastDir: "", LastTick: 0, PrevSpeed: 0, Sending: false
        , CriterionCallback: false, ModifierCriterionCallback: false
        , WheelUpHotkey: "~$WheelUp", WheelDownHotkey: "~$WheelDown"
        , ModifierWheelUpHotkey: "~*$WheelUp", ModifierWheelDownHotkey: "~*$WheelDown"
        , WheelUpCallback: false, WheelDownCallback: false, ModifierWheelCallback: false
        , WheelUpRegistered: false, WheelDownRegistered: false
        , ModifierWheelUpRegistered: false, ModifierWheelDownRegistered: false}
    state.Taskbar := {Initialized: false, CleanupStarted: false, Candidate: false
        , CandidateLifetimeMs: 100, AncestryMaxDepth: 20, StartDesktopTogglePending: false
        , TaskButtonProbeCandidateLifetimeMs: 500, MinimizeStacks: {}
        , MiddleClickCandidate: false, MiddleClickHotkeyName: "$MButton"
        , MiddleClickCriterionCallback: false, MiddleClickCallback: false
        , MiddleClickRegistered: false}
    state.TrayWheelVolume := {Initialized: false, CleanupStarted: false
        , Candidate: false, CandidateLifetimeMs: 100
        , AccelLastTick: 0, AccelDirection: ""}
    state.TrayMiddleClickMute := {Initialized: false, CleanupStarted: false
        , Candidate: false, CandidateLifetimeMs: 100, HotkeyName: "$MButton"
        , CriterionCallback: false, MiddleClickCallback: false, Registered: false}
    state.VolumeOverlay := {Initialized: false, CleanupStarted: false
        , GuiCreated: false, BaseGuiName: "", FillGuiName: "", ValueGuiName: ""
        , BaseHwnd: 0, FillHwnd: 0, ValueHwnd: 0
        , NumberControlHwnd: 0, MuteControlHwnd: 0
        , UpdateTimerCallback: false, UpdateTimerRegistered: false
        , UpdateTimerRunning: false, HideTimerCallback: false
        , HideTimerRegistered: false, HideTimerRunning: false
        , UpdateIntervalMs: 25, QuietMs: 100, LastRequestTick: 0
        , Pending: false, Visible: false, BarWidth: 200, BarHeight: 24
        , NumberWidth: 48, NumberHeight: 32, RightMargin: 10, BottomMargin: 50}
    state.WheelInput := {Initialized: false, CleanupStarted: false
        , CriterionCallback: false
        , WheelUpHotkey: "$WheelUp", WheelDownHotkey: "$WheelDown"
        , WheelUpCallback: false, WheelDownCallback: false
        , WheelUpRegistered: false, WheelDownRegistered: false}
    return state
}


; -----------------------------------------------------------------------------
; Native Helper（問い合わせ専用）
; -----------------------------------------------------------------------------

ME_GetPluginDirectory() {
    lineFile := A_LineFile
    SplitPath, lineFile, , dir
    return dir
}

ME_InitializeNative() {
    global ME_State
    state := ME_State.Native
    if (ME_State.CleanupStarted)
        return false
    if (state.Initialized)
        return state.Available
    state.Initialized := true
    state.Available := false
    state.Module := 0
    state.LastLoadError := 0
    state.AppIdProcAddress := 0
    state.VirtualDesktopProcAddress := 0
    module := 0
    try {
        pluginDir := ME_GetPluginDirectory()
        if (pluginDir = "")
            return false
        dllPath := pluginDir "\MouseExtensionNative.dll"
        state.Path := dllPath
        if (!A_IsUnicode || A_PtrSize != 8 || !FileExist(dllPath))
            return false
        DllCall("Kernel32\SetLastError", "UInt", 0)
        module := DllCall("Kernel32\LoadLibraryW", "WStr", dllPath, "Ptr")
        if (!module) {
            state.LastLoadError := DllCall("Kernel32\GetLastError", "UInt")
            return false
        }
        state.AppIdProcAddress := DllCall("Kernel32\GetProcAddress", "Ptr", module
            , "AStr", "ME_GetEffectiveWindowAppUserModelId", "Ptr")
        if (!state.AppIdProcAddress)
            state.LastLoadError := DllCall("Kernel32\GetLastError", "UInt")
        state.VirtualDesktopProcAddress := DllCall("Kernel32\GetProcAddress", "Ptr", module
            , "AStr", "ME_IsWindowOnCurrentVirtualDesktop", "Ptr")
        if (!state.VirtualDesktopProcAddress)
            state.LastLoadError := DllCall("Kernel32\GetLastError", "UInt")
        if (!state.AppIdProcAddress || !state.VirtualDesktopProcAddress)
            return false
        state.Module := module
        state.Available := true
        module := 0 ; 所有権をstateへ移し、Cleanupで一度だけ解放する。
        return true
    } catch error {
        state.Module := 0
        state.Available := false
        return false
    } finally {
        if (module) {
            closingModule := module
            module := 0
            try {
                DllCall("Kernel32\FreeLibrary", "Ptr", closingModule, "Int")
            } catch cleanupError {
            }
        }
    }
}

ME_Native_Cleanup() {
    global ME_State
    state := ME_State.Native
    module := state.Module
    state.Module := 0 ; 解放前に切り離し、再入時の二重解放を防ぐ。
    state.Available := false
    state.Initialized := false
    state.Path := ""
    state.LastLoadError := 0
    state.AppIdProcAddress := 0
    state.VirtualDesktopProcAddress := 0
    if (module) {
        try {
            DllCall("Kernel32\FreeLibrary", "Ptr", module, "Int")
        } catch error {
        }
    }
}

ME_Native_GetEffectiveWindowAppUserModelId(hwnd) {
    global ME_State
    state := ME_State.Native
    try {
        if (ME_State.CleanupStarted || !state.Initialized || !state.Available || !state.Module
            || !hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
            return ""
        address := DllCall("Kernel32\GetProcAddress", "Ptr", state.Module
            , "AStr", "ME_GetEffectiveWindowAppUserModelId", "Ptr")
        if (!address)
            return ""
        cchBuffer := 512
        Loop, 2 {
            if (VarSetCapacity(buffer, cchBuffer * 2, 0) < cchBuffer * 2)
                return ""
            result := DllCall(address, "Ptr", hwnd, "Ptr", &buffer, "UInt", cchBuffer, "Int")
            if (ErrorLevel)
                return ""
            if (result = 1)
                return StrGet(&buffer, "UTF-16")
            if (result != -2)
                return ""
            cchBuffer := 4096 ; buffer不足の場合だけ一度再試行する。
        }
        return ""
    } catch error {
        return ""
    }
}

ME_Native_IsWindowOnCurrentVirtualDesktop(hwnd) {
    global ME_State
    state := ME_State.Native
    try {
        if (ME_State.CleanupStarted || !state.Initialized || !state.Available || !state.Module)
            return -2
        if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
            return -1
        address := DllCall("Kernel32\GetProcAddress", "Ptr", state.Module
            , "AStr", "ME_IsWindowOnCurrentVirtualDesktop", "Ptr")
        if (!address)
            return -2
        result := DllCall(address, "Ptr", hwnd, "Int")
        if (ErrorLevel || StrLen(result) = 0)
            return -2
        if (result = 1 || result = 0 || result = -1 || result = -2)
            return result
        return -2
    } catch error {
        return -2
    }
}


; -----------------------------------------------------------------------------
; UI Automation 共通基盤
; -----------------------------------------------------------------------------
;
; 所有権契約:
; - ElementFromPoint / GetParent / GetPattern / FindAncestor の戻り値は呼出元所有。
; - 引数として受け取るelement pointerは借用であり、この層では解放しない。
; - RawViewWalkerはservice所有の借用参照を返し、Cleanupだけが解放する。
; - PropertyのVARIANT/BSTRはこの層でコピー後にVariantClearし、呼出元へ生値を渡さない。

ME_UIA_EnsureInitialized() {
    global ME_Services
    service := ME_Services.UIA
    initialization := service.Initialization
    if (initialization.State = "Ready" && service.AutomationPtr)
        return true
    ; Failedからの再試行は明示的なRequestInitializationRetry経由だけで許可する。
    if (initialization.State != "NotAttempted")
        return false

    initialization.State := "Initializing"
    clsidCUIAutomation := "{FF48DBA4-60EF-4201-AA87-54103EEF594E}"
    iidIUIAutomation := "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
    try {
        ; IID指定のComObjCreateは参照カウント1の生ポインタを返す。
        automationPtr := ComObjCreate(clsidCUIAutomation, iidIUIAutomation)
    } catch error {
        automationPtr := 0
    }
    if (!automationPtr) {
        initialization.State := "Failed"
        initialization.FailureCount += 1
        initialization.LastFailureTick := A_TickCount
        return false
    }

    service.AutomationPtr := automationPtr
    initialization.State := "Ready"
    return true
}

ME_UIA_RequestInitializationRetry() {
    global ME_Services, ME_State
    initialization := ME_Services.UIA.Initialization
    if (ME_State.CleanupStarted || initialization.State != "Failed")
        return false
    ; 再試行ポリシーはここでは決めない。明示要求1回につき次の初期化1回だけを許可する。
    initialization.State := "NotAttempted"
    return true
}

ME_UIA_ElementFromPoint(screenX, screenY, useCache := true) {
    global ME_Services
    if (!ME_UIA_EnsureInitialized())
        return 0

    service := ME_Services.UIA
    cache := service.HitTestCache
    hwnd := ME_WindowFromScreenPoint(screenX, screenY)
    elapsed := A_TickCount - cache.Tick
    if (useCache && cache.Valid && elapsed >= 0 && elapsed <= cache.DurationMs
        && cache.X = screenX && cache.Y = screenY && cache.Hwnd = hwnd
        && cache.ElementPtr) {
        ; キャッシュと呼出元がそれぞれ1参照を所有する。
        ME_ComAddRef(cache.ElementPtr)
        return cache.ElementPtr
    }

    packedPoint := ME_PackPoint64(screenX, screenY)
    elementPtr := 0
    method := ME_ComMethod(service.AutomationPtr, 7) ; IUIAutomation::ElementFromPoint
    if (!method)
        return 0
    hresult := DllCall(method, "Ptr", service.AutomationPtr, "Int64", packedPoint
        , "PtrP", elementPtr, "Int")
    if (hresult < 0 || !elementPtr)
        return 0

    ME_UIA_ClearHitTestCache()
    ; ElementFromPointの参照は呼出元へ渡し、キャッシュ分をAddRefする。
    if (ME_ComAddRef(elementPtr)) {
        cache.Valid := true
        cache.X := screenX
        cache.Y := screenY
        cache.Hwnd := hwnd
        cache.ElementPtr := elementPtr
        cache.Tick := A_TickCount
    }
    return elementPtr
}

ME_UIA_GetRawViewWalker() {
    global ME_Services
    if (!ME_UIA_EnsureInitialized())
        return 0
    service := ME_Services.UIA
    if (service.RawViewWalkerPtr)
        return service.RawViewWalkerPtr ; 借用参照。呼出元は解放しない。

    walkerPtr := 0
    method := ME_ComMethod(service.AutomationPtr, 16) ; IUIAutomation::get_RawViewWalker
    if (!method)
        return 0
    hresult := DllCall(method, "Ptr", service.AutomationPtr, "PtrP", walkerPtr, "Int")
    if (hresult < 0 || !walkerPtr)
        return 0
    service.RawViewWalkerPtr := walkerPtr ; serviceが所有しCleanupで解放する。
    return walkerPtr
}

ME_UIA_GetParent(elementPtr) {
    if (!elementPtr)
        return 0
    walkerPtr := ME_UIA_GetRawViewWalker()
    if (!walkerPtr)
        return 0

    parentPtr := 0
    method := ME_ComMethod(walkerPtr, 3) ; IUIAutomationTreeWalker::GetParentElement
    if (!method)
        return 0
    hresult := DllCall(method, "Ptr", walkerPtr, "Ptr", elementPtr, "PtrP", parentPtr, "Int")
    if (hresult < 0 || !parentPtr)
        return 0
    return parentPtr ; 呼出元所有。不要になったらME_ComReleaseで解放する。
}

ME_UIA_FindAncestor(elementPtr, predicate, maxDepth := 20, includeSelf := false) {
    if (!elementPtr || maxDepth < 1)
        return 0

    if (includeSelf) {
        currentPtr := elementPtr
        ME_ComAddRef(currentPtr)
    } else {
        currentPtr := ME_UIA_GetParent(elementPtr)
    }

    depth := 0
    while (currentPtr && depth < maxDepth) {
        depth += 1
        if (ME_UIA_CallPredicate(predicate, currentPtr))
            return currentPtr ; 呼出元所有。
        nextPtr := ME_UIA_GetParent(currentPtr)
        ME_ComRelease(currentPtr)
        currentPtr := nextPtr
    }
    if (currentPtr)
        ME_ComRelease(currentPtr)
    return 0
}

ME_UIA_CallPredicate(predicate, elementPtr) {
    if (!IsObject(predicate)) {
        if (!IsFunc(predicate))
            return false
        predicate := Func(predicate)
    }
    try {
        matched := predicate.Call(elementPtr)
    } catch error {
        return false
    }
    return matched ? true : false
}

ME_UIA_GetProperty(elementPtr, propertyId, ByRef value) {
    value := ""
    if (!elementPtr || !ME_IsIntegerString(Trim(propertyId)))
        return false

    VarSetCapacity(variant, 16, 0)
    method := ME_ComMethod(elementPtr, 10) ; IUIAutomationElement::GetCurrentPropertyValue
    if (!method)
        return false
    hresult := DllCall(method, "Ptr", elementPtr, "Int", propertyId + 0, "Ptr", &variant, "Int")
    if (hresult < 0) {
        DllCall("OleAut32\VariantClear", "Ptr", &variant)
        return false
    }

    succeeded := ME_UIA_CopyVariantScalar(variant, value)
    ; VT_BSTRを含むVARIANTの所有物はVariantClearが解放する。個別SysFreeStringは禁止。
    DllCall("OleAut32\VariantClear", "Ptr", &variant)
    return succeeded
}

ME_UIA_CopyVariantScalar(ByRef variant, ByRef value) {
    variantType := NumGet(variant, 0, "UShort")
    if (variantType = 0 || variantType = 1) { ; VT_EMPTY / VT_NULL
        value := ""
        return true
    }
    if (variantType = 3) { ; VT_I4
        value := NumGet(variant, 8, "Int")
        return true
    }
    if (variantType = 19) { ; VT_UI4
        value := NumGet(variant, 8, "UInt")
        return true
    }
    if (variantType = 20) { ; VT_I8
        value := NumGet(variant, 8, "Int64")
        return true
    }
    if (variantType = 21) { ; VT_UI8 (AHK v1では符号付き64bit範囲で保持)
        value := NumGet(variant, 8, "Int64")
        return true
    }
    if (variantType = 5) { ; VT_R8
        value := NumGet(variant, 8, "Double")
        return true
    }
    if (variantType = 11) { ; VT_BOOL
        value := NumGet(variant, 8, "Short") != 0
        return true
    }
    if (variantType = 8) { ; VT_BSTR
        bstrPtr := NumGet(variant, 8, "Ptr")
        value := bstrPtr ? StrGet(bstrPtr, "UTF-16") : ""
        return true
    }
    ; 配列、IUnknown等はPhase 1では解釈せずfail-closedにする。
    return false
}

ME_UIA_GetPattern(elementPtr, patternId) {
    if (!elementPtr || !ME_IsIntegerString(Trim(patternId)))
        return 0
    patternPtr := 0
    method := ME_ComMethod(elementPtr, 16) ; IUIAutomationElement::GetCurrentPattern
    if (!method)
        return 0
    hresult := DllCall(method, "Ptr", elementPtr, "Int", patternId + 0, "PtrP", patternPtr, "Int")
    if (hresult < 0 || !patternPtr)
        return 0
    return patternPtr ; 呼出元所有。ME_ComReleaseで解放する。
}

ME_UIA_AreSameElement(firstPtr, secondPtr, ByRef areSame) {
    global ME_Services
    areSame := false
    if (!firstPtr || !secondPtr || !ME_UIA_EnsureInitialized())
        return false
    method := ME_ComMethod(ME_Services.UIA.AutomationPtr, 3) ; IUIAutomation::CompareElements
    if (!method)
        return false
    nativeSame := 0
    hresult := DllCall(method, "Ptr", ME_Services.UIA.AutomationPtr
        , "Ptr", firstPtr, "Ptr", secondPtr, "IntP", nativeSame, "Int")
    if (hresult < 0)
        return false
    areSame := nativeSame ? true : false
    return true
}

ME_UIA_ClearHitTestCache() {
    global ME_Services
    cache := ME_Services.UIA.HitTestCache
    if (cache.ElementPtr) {
        ownedPtr := cache.ElementPtr
        cache.ElementPtr := 0
        ME_ComRelease(ownedPtr)
    }
    cache.Valid := false
    cache.X := 0
    cache.Y := 0
    cache.Hwnd := 0
    cache.Tick := 0
}

ME_UIA_Cleanup() {
    global ME_Services
    ME_UIA_ClearHitTestCache()
    service := ME_Services.UIA
    if (service.RawViewWalkerPtr) {
        ownedPtr := service.RawViewWalkerPtr
        service.RawViewWalkerPtr := 0
        ME_ComRelease(ownedPtr)
    }
    if (service.AutomationPtr) {
        ownedPtr := service.AutomationPtr
        service.AutomationPtr := 0
        ME_ComRelease(ownedPtr)
    }
    service.Initialization.State := "Stopped"
}

ME_ComMethod(interfacePtr, methodIndex) {
    if (!interfacePtr)
        return 0
    vtablePtr := NumGet(interfacePtr + 0, 0, "Ptr")
    if (!vtablePtr)
        return 0
    return NumGet(vtablePtr + methodIndex * A_PtrSize, 0, "Ptr")
}

ME_ComAddRef(interfacePtr) {
    method := ME_ComMethod(interfacePtr, 1)
    if (!method)
        return 0
    return DllCall(method, "Ptr", interfacePtr, "UInt")
}

ME_ComRelease(interfacePtr) {
    ; 渡された所有参照を1回だけ解放する。呼出側は保持変数を先に0へ戻す。
    method := ME_ComMethod(interfacePtr, 2)
    if (!method)
        return 0
    return DllCall(method, "Ptr", interfacePtr, "UInt")
}


; -----------------------------------------------------------------------------
; 座標と共通ヒットテスト
; -----------------------------------------------------------------------------

ME_GetCursorScreenPoint(ByRef screenX, ByRef screenY) {
    VarSetCapacity(point, 8, 0)
    if (!DllCall("User32\GetCursorPos", "Ptr", &point, "Int"))
        return false
    ; LONGとして読むことで負の仮想スクリーン座標を保持する。
    screenX := NumGet(point, 0, "Int")
    screenY := NumGet(point, 4, "Int")
    return true
}

ME_WindowFromScreenPoint(screenX, screenY) {
    packedPoint := ME_PackPoint64(screenX, screenY)
    return DllCall("User32\WindowFromPoint", "Int64", packedPoint, "Ptr")
}

ME_GetWindowRectangle(hwnd, ByRef rectangle) {
    rectangle := false
    if (!hwnd)
        return false
    VarSetCapacity(nativeRect, 16, 0)
    if (!DllCall("User32\GetWindowRect", "Ptr", hwnd, "Ptr", &nativeRect, "Int"))
        return false
    left := NumGet(nativeRect, 0, "Int")
    top := NumGet(nativeRect, 4, "Int")
    right := NumGet(nativeRect, 8, "Int")
    bottom := NumGet(nativeRect, 12, "Int")
    rectangle := {Left: left, Top: top, Right: right, Bottom: bottom
        , Width: right - left, Height: bottom - top}
    return true
}

ME_ScreenToWindowPoint(hwnd, screenX, screenY, ByRef windowX, ByRef windowY) {
    if (!ME_GetWindowRectangle(hwnd, rectangle))
        return false
    windowX := screenX - rectangle.Left
    windowY := screenY - rectangle.Top
    return true
}

ME_ScreenToClientPoint(hwnd, screenX, screenY, ByRef clientX, ByRef clientY) {
    if (!hwnd)
        return false
    VarSetCapacity(point, 8, 0)
    NumPut(screenX, point, 0, "Int")
    NumPut(screenY, point, 4, "Int")
    if (!DllCall("User32\ScreenToClient", "Ptr", hwnd, "Ptr", &point, "Int"))
        return false
    clientX := NumGet(point, 0, "Int")
    clientY := NumGet(point, 4, "Int")
    return true
}

ME_HitTestScreenPoint(screenX, screenY, useCache := true) {
    global ME_Services
    cache := ME_Services.HitTest
    hwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (cache.Valid && cache.Hwnd != hwnd)
        ME_ClearHitTestCache()
    elapsed := A_TickCount - cache.Tick
    if (useCache && cache.Valid && elapsed >= 0 && elapsed <= cache.DurationMs
        && cache.X = screenX && cache.Y = screenY && cache.Hwnd = hwnd)
        return ME_CopyHitTestResult(cache.Result)

    if (!hwnd || !ME_GetWindowRectangle(hwnd, rectangle))
        return false
    hasClientPoint := ME_ScreenToClientPoint(hwnd, screenX, screenY, clientX, clientY)
    result := {ScreenX: screenX, ScreenY: screenY, Hwnd: hwnd, Rectangle: rectangle
        , HasClientPoint: hasClientPoint, ClientX: clientX, ClientY: clientY}

    cache.Valid := true
    cache.X := screenX
    cache.Y := screenY
    cache.Hwnd := hwnd
    cache.Tick := A_TickCount
    cache.Result := result
    return ME_CopyHitTestResult(result)
}

ME_CopyHitTestResult(source) {
    if (!IsObject(source))
        return false
    sourceRect := source.Rectangle
    copiedRect := {Left: sourceRect.Left, Top: sourceRect.Top, Right: sourceRect.Right
        , Bottom: sourceRect.Bottom, Width: sourceRect.Width, Height: sourceRect.Height}
    return {ScreenX: source.ScreenX, ScreenY: source.ScreenY, Hwnd: source.Hwnd
        , Rectangle: copiedRect, HasClientPoint: source.HasClientPoint
        , ClientX: source.ClientX, ClientY: source.ClientY}
}

ME_SendNcHitTest(hwnd, screenX, screenY, timeoutMs := 50) {
    ; WM_NCHITTESTのLPARAMは符号付き16bit座標を下位ワードへ詰める。
    result := 0
    if (!hwnd)
        return {Succeeded: false, Result: 0}
    packedLParam := (screenX & 0xFFFF) | ((screenY & 0xFFFF) << 16)
    succeeded := DllCall("User32\SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0x84
        , "Ptr", 0, "Ptr", packedLParam, "UInt", 0x2, "UInt", timeoutMs
        , "PtrP", result, "Ptr")
    return {Succeeded: succeeded ? true : false, Result: result}
}

ME_PackPoint64(x, y) {
    return (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32)
}

ME_ClearHitTestCache() {
    global ME_Services
    cache := ME_Services.HitTest
    cache.Valid := false
    cache.Result := false
    cache.Hwnd := 0
    cache.Tick := 0
}


; -----------------------------------------------------------------------------
; Always On Top (Phase 2-1)
; -----------------------------------------------------------------------------

ME_InitializeAlwaysOnTop() {
    global ME_Config, ME_Product, ME_State
    state := ME_State.AlwaysOnTop
    if (state.Initialized)
        return true
    state.Initialized := true

    if (!ME_Config.EnableFunction.AlwaysOnTop || ME_MouseGestureL_IsEditMode())
        return true

    processId := DllCall("Kernel32\GetCurrentProcessId", "UInt")
    state.IdentityPropertyName := ME_Product.Name . "_AOT_" . processId . "_" . A_TickCount
    state.HotkeyCallback := Func("ME_AlwaysOnTop_OnShiftLeftButton")
    ; include位置に依存する#If条件を引き継がず、明示的にglobal variantとして登録する。
    hotkeyCallback := state.HotkeyCallback
    Hotkey, If
    Hotkey, % state.HotkeyName, % hotkeyCallback, On UseErrorLevel
    if (ErrorLevel) {
        state.HotkeyCallback := false
        return false
    }
    state.HotkeyRegistered := true

    ; 全管理ウィンドウで共有するtimerは1本だけ生成する。
    state.TimerCallback := Func("ME_AlwaysOnTop_UpdateAllFrames")
    ME_RegisterTimerForCleanup(state.TimerCallback)
    state.TimerRegistered := true
    if (!ME_AlwaysOnTop_InstallWinEventHooks())
        ME_Debug("AlwaysOnTop WinEvent hook unavailable; timer fallback remains active.")
    return true
}

ME_AlwaysOnTop_InstallWinEventHooks() {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (state.WinEventHooksInstalled)
        return true
    if (state.WinEventCallbackPtr)
        return false

    callbackPtr := RegisterCallback("ME_AlwaysOnTop_WinEventProc", "", 7)
    if (!callbackPtr)
        return false
    state.WinEventCallbackPtr := callbackPtr

    ; MOVESIZESTART/ENDとLOCATIONCHANGEだけを受け、自己プロセスの枠イベントは除外する。
    eventRanges := [{Min: 0x000A, Max: 0x000B}
        , {Min: 0x800B, Max: 0x800B}]
    for _, eventRange in eventRanges {
        hookHandle := DllCall("User32\SetWinEventHook"
            , "UInt", eventRange.Min, "UInt", eventRange.Max, "Ptr", 0
            , "Ptr", callbackPtr, "UInt", 0, "UInt", 0, "UInt", 0x2, "Ptr")
        if (!hookHandle) {
            ME_AlwaysOnTop_UninstallWinEventHooks()
            return false
        }
        state.WinEventHooks.Push(hookHandle)
    }
    state.WinEventHooksInstalled := true
    return true
}

ME_AlwaysOnTop_UninstallWinEventHooks() {
    global ME_State
    state := ME_State.AlwaysOnTop
    remainingHooks := []
    allUnhooked := true
    for _, hookHandle in state.WinEventHooks {
        if (hookHandle && !DllCall("User32\UnhookWinEvent", "Ptr", hookHandle, "Int")) {
            remainingHooks.Push(hookHandle)
            allUnhooked := false
        }
    }
    state.WinEventHooks := remainingHooks
    state.WinEventHooksInstalled := allUnhooked ? false : true

    ; Unhook失敗時はOSから再入され得るため、callbackメモリを解放しない。
    if (allUnhooked && state.WinEventCallbackPtr) {
        DllCall("Kernel32\GlobalFree", "Ptr", state.WinEventCallbackPtr, "Ptr")
        state.WinEventCallbackPtr := 0
    }
    return allUnhooked
}

ME_AlwaysOnTop_WinEventProc(hookHandle, event, hwnd, idObject, idChild
    , eventThreadId, eventTime) {
    global ME_State
    Critical, On
    if (!IsObject(ME_State) || !IsObject(ME_State.AlwaysOnTop)
        || ME_State.CleanupStarted || !ME_State.AcceptingInput || !hwnd)
        return
    state := ME_State.AlwaysOnTop
    if (state.CleanupStarted || !state.ManagedWindows.HasKey(hwnd))
        return

    if (event = 0x800B) { ; EVENT_OBJECT_LOCATIONCHANGE
        if (idObject != 0 || idChild != 0) ; OBJID_WINDOW / CHILDID_SELF
            return
        ME_AlwaysOnTop_UpdateManagedWindow(hwnd)
    } else if (event = 0x000A) { ; EVENT_SYSTEM_MOVESIZESTART
        ME_AlwaysOnTop_BeginMoveSize(hwnd)
    } else if (event = 0x000B) { ; EVENT_SYSTEM_MOVESIZEEND
        ME_AlwaysOnTop_EndMoveSize(hwnd)
    }
}

ME_AlwaysOnTop_OnShiftLeftButton() {
    global ME_Config, ME_State
    Critical, On
    if (!ME_Config.EnableFunction.AlwaysOnTop || !ME_CanRouteMouseInput())
        return
    if (ME_State.SyntheticInputDepth > 0 || !ME_AlwaysOnTop_IsShiftOnly())
        return
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return

    targetHwnd := ME_ResolveTitleBarTarget(screenX, screenY)
    if (!targetHwnd) {
        ME_Debug("AlwaysOnTop: strict HTCAPTION failed.")
        targetHwnd := ME_AlwaysOnTop_ResolveExplorerTopBlank(screenX, screenY)
    }
    if (!targetHwnd)
        return
    ME_AlwaysOnTop_Toggle(targetHwnd)
}

ME_AlwaysOnTop_IsShiftOnly() {
    if (!GetKeyState("Shift", "P"))
        return false
    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P")
        || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        return false
    return true
}

ME_AlwaysOnTop_ResolveExplorerTopBlank(screenX, screenY) {
    global ME_State

    Critical, On
    state := ME_State.AlwaysOnTop
    if (ME_State.CleanupStarted || !ME_State.AcceptingInput || state.CleanupStarted)
        return 0
    if (state.ExplorerFallbackBusy)
        return 0
    state.ExplorerFallbackBusy := true

    ; UIA呼び出し中は他threadを必要以上に遮断しない。Busyが再入を拒否する。
    Critical, Off
    targetHwnd := 0
    try {
        targetHwnd := ME_AlwaysOnTop_ResolveExplorerTopBlankCore(screenX, screenY)
        ; local UIA sessionが全Releaseされた後に、Win32側で対象を再確認する。
        if (targetHwnd) {
            if (!ME_AlwaysOnTop_RevalidateExplorerTopBlank(targetHwnd
                , screenX, screenY)) {
                targetHwnd := 0
            }
        }
    } catch error {
        targetHwnd := 0
    } finally {
        Critical, On
        state.ExplorerFallbackBusy := false
    }
    return targetHwnd
}

ME_AlwaysOnTop_ResolveExplorerTopBlankCore(screenX, screenY) {
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd)
        || !ME_AlwaysOnTop_GetWindowIdentity(pointHwnd, pointProcessId
            , pointThreadId, pointClass)) {
        return 0
    }
    rootHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!ME_AlwaysOnTop_IsExplorerWindow(rootHwnd))
        return 0

    bridgePrefix := "Microsoft.UI.Content.DesktopChildSiteBridge"
    if (!(SubStr(pointClass, 1, StrLen(bridgePrefix)) == bridgePrefix
        || pointClass == "TITLE_BAR_SCAFFOLDING_WINDOW_CLASS"))
        return 0

    ; Explorer fallback専用の短寿命session。共有UIA serviceへは保存しない。
    automationPtr := 0
    walkerPtr := 0
    elementPtr := 0
    currentPtr := 0
    parentPtr := 0
    try {
        clsidCUIAutomation := "{FF48DBA4-60EF-4201-AA87-54103EEF594E}"
        iidIUIAutomation := "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
        try {
            automationPtr := ComObjCreate(clsidCUIAutomation, iidIUIAutomation)
        } catch createError {
            automationPtr := 0
        }
        if (!automationPtr)
            return 0

        elementMethod := ME_ComMethod(automationPtr, 7) ; ElementFromPoint
        if (!elementMethod)
            return 0
        packedPoint := ME_PackPoint64(screenX, screenY)
        elementHresult := DllCall(elementMethod, "Ptr", automationPtr
            , "Int64", packedPoint, "PtrP", elementPtr, "Int")
        if (elementHresult < 0 || !elementPtr)
            return 0

        elementControlType := "?"
        elementName := "?"
        if (!ME_UIA_GetProperty(elementPtr, 30003, elementControlType)
            || !ME_UIA_GetProperty(elementPtr, 30005, elementName)
            || elementControlType != 50037
            || !(elementName == "" || elementName == "TitleBar")) {
            return 0
        }

        walkerMethod := ME_ComMethod(automationPtr, 16) ; get_RawViewWalker
        if (!walkerMethod)
            return 0
        walkerHresult := DllCall(walkerMethod, "Ptr", automationPtr
            , "PtrP", walkerPtr, "Int")
        if (walkerHresult < 0 || !walkerPtr)
            return 0

        parentPtr := ME_AlwaysOnTop_UIA_GetParentLocal(walkerPtr, elementPtr)
        currentPtr := parentPtr
        parentPtr := 0
        ownedPtr := elementPtr
        elementPtr := 0
        ME_ComRelease(ownedPtr)

        depth := 0
        while (currentPtr && depth < 10) {
            depth += 1
            ancestorControlType := "?"
            ancestorClassName := "?"
            ancestorFrameworkId := "?"
            if (!ME_UIA_GetProperty(currentPtr, 30003, ancestorControlType)
                || !ME_UIA_GetProperty(currentPtr, 30012, ancestorClassName)
                || !ME_UIA_GetProperty(currentPtr, 30024, ancestorFrameworkId))
                return 0
            if (ancestorControlType = 50032
                && ancestorClassName == "CabinetWClass"
                && ancestorFrameworkId == "Win32") {
                return rootHwnd
            }
            if (depth >= 10)
                break
            parentPtr := ME_AlwaysOnTop_UIA_GetParentLocal(walkerPtr, currentPtr)
            ownedPtr := currentPtr
            currentPtr := parentPtr
            parentPtr := 0
            ME_ComRelease(ownedPtr)
        }
        return 0
    } finally {
        if (parentPtr) {
            ownedPtr := parentPtr
            parentPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (currentPtr) {
            ownedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (walkerPtr) {
            ownedPtr := walkerPtr
            walkerPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (elementPtr) {
            ownedPtr := elementPtr
            elementPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (automationPtr) {
            ownedPtr := automationPtr
            automationPtr := 0
            ME_ComRelease(ownedPtr)
        }
    }
}

ME_AlwaysOnTop_UIA_GetParentLocal(walkerPtr, elementPtr) {
    if (!walkerPtr || !elementPtr)
        return 0
    parentPtr := 0
    method := ME_ComMethod(walkerPtr, 3) ; IUIAutomationTreeWalker::GetParentElement
    if (!method)
        return 0
    hresult := DllCall(method, "Ptr", walkerPtr, "Ptr", elementPtr
        , "PtrP", parentPtr, "Int")
    if (hresult < 0 || !parentPtr) {
        if (parentPtr)
            ME_ComRelease(parentPtr)
        return 0
    }
    return parentPtr ; 呼出元owned。
}

ME_AlwaysOnTop_IsExplorerWindow(hwnd) {
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd)
        || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className)
        || !(className == "CabinetWClass"))
        return false

    ; class名だけでは受理せず、同じHWNDの所有process imageもexplorer.exeと確認する。
    if (!ME_OpenExeFolder_GetExecutablePath(hwnd, imagePath
        , verifiedProcessId, verifiedThreadId)
        || verifiedProcessId != processId || verifiedThreadId != threadId)
        return false
    SplitPath, imagePath, imageFileName
    return (imageFileName = "explorer.exe") ? true : false
}

ME_AlwaysOnTop_RevalidateExplorerTopBlank(rootHwnd, screenX, screenY) {
    global ME_State
    if (ME_State.CleanupStarted || !ME_State.AcceptingInput
        || ME_State.AlwaysOnTop.CleanupStarted
        || !ME_AlwaysOnTop_IsExplorerWindow(rootHwnd))
        return false
    currentHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentHwnd || ME_AlwaysOnTop_IsFrameWindow(currentHwnd))
        return false
    currentRootHwnd := DllCall("User32\GetAncestor", "Ptr", currentHwnd
        , "UInt", 2, "Ptr")
    return (currentRootHwnd = rootHwnd) ? true : false
}

ME_ResolveTitleBarTarget(screenX, screenY) {
    hit := ME_HitTestScreenPoint(screenX, screenY)
    if (!IsObject(hit) || !hit.Hwnd || ME_AlwaysOnTop_IsFrameWindow(hit.Hwnd))
        return 0

    targetHwnd := DllCall("User32\GetAncestor", "Ptr", hit.Hwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return 0
    if (!ME_GetWindowRectangle(targetHwnd, rectangle))
        return 0
    if (screenX < rectangle.Left || screenX >= rectangle.Right
        || screenY < rectangle.Top || screenY >= rectangle.Bottom)
        return 0

    hitTest := ME_SendNcHitTest(targetHwnd, screenX, screenY, 50)
    if (!hitTest.Succeeded || hitTest.Result != 2) ; HTCAPTION
        return 0

    ; メッセージ処理中の破棄・差し替わりを考慮し、直後に同じrootか再確認する。
    currentHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentHwnd || ME_AlwaysOnTop_IsFrameWindow(currentHwnd))
        return 0
    currentRoot := DllCall("User32\GetAncestor", "Ptr", currentHwnd, "UInt", 2, "Ptr")
    if (currentRoot != targetHwnd || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return 0
    return targetHwnd
}

ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd) {
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    if (!DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int"))
        return false
    if (ME_AlwaysOnTop_IsFrameWindow(hwnd))
        return false
    if (!ME_AlwaysOnTop_GetWindowStyle(hwnd, -16, style)) ; GWL_STYLE
        return false
    if (style & 0x40000000) ; WS_CHILD
        return false
    rootHwnd := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    return (rootHwnd = hwnd)
}

ME_AlwaysOnTop_Toggle(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd))
        return false

    if (state.ManagedWindows.HasKey(hwnd)) {
        record := state.ManagedWindows[hwnd]
        if (!ME_AlwaysOnTop_IsTrackedWindowValid(record))
            ME_AlwaysOnTop_DiscardRecord(hwnd, false)
    }

    if (!ME_AlwaysOnTop_GetTopmost(hwnd, isTopmost))
        return false
    if (isTopmost) {
        if (!ME_AlwaysOnTop_SetTopmost(hwnd, false))
            return false
        if (state.ManagedWindows.HasKey(hwnd))
            ME_AlwaysOnTop_DiscardRecord(hwnd, true)
        return true
    }

    ; 外部操作でOFFになった管理記録は、新たに所有権を取得する前に破棄する。
    if (state.ManagedWindows.HasKey(hwnd))
        ME_AlwaysOnTop_DiscardRecord(hwnd, true)
    return ME_AlwaysOnTop_EnableManaged(hwnd)
}

ME_AlwaysOnTop_EnableManaged(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!ME_AlwaysOnTop_CaptureIdentity(hwnd, identity))
        return false
    if (!ME_AlwaysOnTop_IsTrackedWindowValid(identity)) {
        ME_AlwaysOnTop_RemoveIdentityProperty(identity)
        return false
    }

    if (!ME_AlwaysOnTop_SetTopmost(hwnd, true)) {
        ME_AlwaysOnTop_RemoveIdentityProperty(identity)
        return false
    }
    if (!ME_AlwaysOnTop_IsTrackedWindowValid(identity)) {
        ME_AlwaysOnTop_RemoveIdentityProperty(identity)
        return false
    }

    record := {Hwnd: hwnd, ProcessId: identity.ProcessId, ThreadId: identity.ThreadId
        , ClassName: identity.ClassName, IdentityToken: identity.IdentityToken
        , Frames: [], FramesVisible: false, FrameRectangle: false}
    state.ManagedWindows[hwnd] := record

    if (!ME_AlwaysOnTop_CreateFrames(record)) {
        ME_AlwaysOnTop_DestroyFrames(record)
        if (ME_AlwaysOnTop_IsTrackedWindowValid(record)) {
            ME_AlwaysOnTop_SetTopmost(hwnd, false)
            ME_AlwaysOnTop_RemoveIdentityProperty(record)
        }
        state.ManagedWindows.Delete(hwnd)
        return false
    }

    ME_AlwaysOnTop_UpdateFrame(record)
    ME_AlwaysOnTop_StartTimer()
    return true
}

ME_AlwaysOnTop_GetTopmost(hwnd, ByRef isTopmost) {
    isTopmost := false
    if (!ME_AlwaysOnTop_GetWindowStyle(hwnd, -20, extendedStyle)) ; GWL_EXSTYLE
        return false
    isTopmost := (extendedStyle & 0x8) ? true : false ; WS_EX_TOPMOST
    return true
}

ME_AlwaysOnTop_GetWindowStyle(hwnd, index, ByRef value) {
    value := 0
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    DllCall("Kernel32\SetLastError", "UInt", 0)
    if (A_PtrSize = 8)
        value := DllCall("User32\GetWindowLongPtrW", "Ptr", hwnd, "Int", index, "UPtr")
    else
        value := DllCall("User32\GetWindowLongW", "Ptr", hwnd, "Int", index, "UInt")
    return !(value = 0 && A_LastError != 0)
}

ME_AlwaysOnTop_SetTopmost(hwnd, enableTopmost) {
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    insertAfter := enableTopmost ? -1 : -2 ; HWND_TOPMOST / HWND_NOTOPMOST
    succeeded := DllCall("User32\SetWindowPos", "Ptr", hwnd, "Ptr", insertAfter
        , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13, "Int")
    if (!succeeded || !ME_AlwaysOnTop_GetTopmost(hwnd, currentTopmost))
        return false
    return (currentTopmost = (enableTopmost ? true : false))
}

ME_AlwaysOnTop_CaptureIdentity(hwnd, ByRef identity) {
    global ME_State
    identity := false
    state := ME_State.AlwaysOnTop
    if (!ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className))
        return false

    token := state.NextIdentityToken
    state.NextIdentityToken += 1
    if (state.NextIdentityToken > 0x7FFFFFFF)
        state.NextIdentityToken := 1
    if (!DllCall("User32\SetPropW", "Ptr", hwnd, "Str", state.IdentityPropertyName
        , "Ptr", token, "Int"))
        return false
    identity := {Hwnd: hwnd, ProcessId: processId, ThreadId: threadId
        , ClassName: className, IdentityToken: token}
    return true
}

ME_AlwaysOnTop_GetWindowIdentity(hwnd, ByRef processId, ByRef threadId, ByRef className) {
    processId := 0
    threadId := 0
    className := ""
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    threadId := DllCall("User32\GetWindowThreadProcessId", "Ptr", hwnd
        , "UIntP", processId, "UInt")
    if (!threadId || !processId)
        return false
    VarSetCapacity(classBuffer, 512, 0)
    length := DllCall("User32\GetClassNameW", "Ptr", hwnd, "Ptr", &classBuffer
        , "Int", 256, "Int")
    if (length <= 0)
        return false
    className := StrGet(&classBuffer, length, "UTF-16")
    return true
}

ME_AlwaysOnTop_IsTrackedWindowValid(record) {
    global ME_State
    if (!IsObject(record) || !record.Hwnd
        || !DllCall("User32\IsWindow", "Ptr", record.Hwnd, "Int"))
        return false
    state := ME_State.AlwaysOnTop
    token := DllCall("User32\GetPropW", "Ptr", record.Hwnd
        , "Str", state.IdentityPropertyName, "Ptr")
    if (token != record.IdentityToken)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(record.Hwnd, processId, threadId, className))
        return false
    return (processId = record.ProcessId && threadId = record.ThreadId
        && className == record.ClassName)
}

ME_AlwaysOnTop_RemoveIdentityProperty(record) {
    global ME_State
    if (!IsObject(record) || !record.Hwnd
        || !DllCall("User32\IsWindow", "Ptr", record.Hwnd, "Int"))
        return false
    state := ME_State.AlwaysOnTop
    token := DllCall("User32\GetPropW", "Ptr", record.Hwnd
        , "Str", state.IdentityPropertyName, "Ptr")
    if (token != record.IdentityToken)
        return false
    DllCall("User32\RemovePropW", "Ptr", record.Hwnd
        , "Str", state.IdentityPropertyName, "Ptr")
    return true
}

ME_AlwaysOnTop_CreateFrames(record) {
    global ME_Config, ME_State
    state := ME_State.AlwaysOnTop
    processId := DllCall("Kernel32\GetCurrentProcessId", "UInt")
    frameColor := ME_Config.AlwaysOnTop.FrameColor

    for _, side in ["Top", "Bottom", "Left", "Right"] {
        serial := state.NextFrameSerial
        state.NextFrameSerial += 1
        guiName := "ME_AOTF_" . processId . "_" . serial . "_" . side
        frameHwnd := 0
        options := "+AlwaysOnTop -Caption +ToolWindow +E0x08080020 +Owner"
            . record.Hwnd . " +HwndframeHwnd"
        Gui, %guiName%:New, %options%
        if (!frameHwnd) {
            ME_AlwaysOnTop_DestroyFrames(record)
            return false
        }
        Gui, %guiName%:Color, %frameColor%
        ; WS_EX_LAYERED + WS_EX_TRANSPARENT + WS_EX_NOACTIVATE。表示は不透明、入力は透過。
        if (!DllCall("User32\SetLayeredWindowAttributes", "Ptr", frameHwnd
            , "UInt", 0, "UChar", 255, "UInt", 0x2, "Int")) {
            Gui, %guiName%:Destroy
            ME_AlwaysOnTop_DestroyFrames(record)
            return false
        }
        if (!DllCall("User32\SetPropW", "Ptr", frameHwnd
            , "Str", state.IdentityPropertyName, "Ptr", record.IdentityToken, "Int")) {
            Gui, %guiName%:Destroy
            ME_AlwaysOnTop_DestroyFrames(record)
            return false
        }
        frame := {Name: guiName, Hwnd: frameHwnd, Side: side}
        record.Frames.Push(frame)
        state.FrameWindows[frameHwnd] := {OwnerHwnd: record.Hwnd
            , IdentityToken: record.IdentityToken}
    }
    return true
}

ME_AlwaysOnTop_UpdateAllFrames() {
    global ME_State
    Critical, On
    state := ME_State.AlwaysOnTop
    if (state.CleanupStarted)
        return

    handles := []
    for hwnd, record in state.ManagedWindows
        handles.Push(hwnd)
    for _, hwnd in handles {
        if (!state.ManagedWindows.HasKey(hwnd))
            continue
        ME_AlwaysOnTop_UpdateManagedWindow(hwnd)
    }
    ME_AlwaysOnTop_StopTimerIfIdle()
}

ME_AlwaysOnTop_UpdateManagedWindow(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!state.ManagedWindows.HasKey(hwnd))
        return false
    record := state.ManagedWindows[hwnd]
    if (!ME_AlwaysOnTop_IsTrackedWindowValid(record)) {
        ME_AlwaysOnTop_DiscardRecord(hwnd, false)
        return false
    }
    if (!ME_AlwaysOnTop_GetTopmost(hwnd, isTopmost) || !isTopmost) {
        ME_AlwaysOnTop_DiscardRecord(hwnd, true)
        return false
    }
    return ME_AlwaysOnTop_UpdateFrame(record)
}

ME_AlwaysOnTop_BeginMoveSize(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!state.ManagedWindows.HasKey(hwnd))
        return
    record := state.ManagedWindows[hwnd]
    if (!ME_AlwaysOnTop_IsTrackedWindowValid(record)) {
        ME_AlwaysOnTop_DiscardRecord(hwnd, false)
        return
    }
    if (!ME_AlwaysOnTop_GetTopmost(hwnd, isTopmost) || !isTopmost) {
        ME_AlwaysOnTop_DiscardRecord(hwnd, true)
        return
    }
    state.MoveSizeWindows[hwnd] := record.IdentityToken
    ME_AlwaysOnTop_RefreshTimerInterval()
    ME_AlwaysOnTop_UpdateFrame(record)
}

ME_AlwaysOnTop_EndMoveSize(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (state.ManagedWindows.HasKey(hwnd))
        ME_AlwaysOnTop_UpdateManagedWindow(hwnd)
    if (state.MoveSizeWindows.HasKey(hwnd))
        state.MoveSizeWindows.Delete(hwnd)
    ME_AlwaysOnTop_RefreshTimerInterval()
}

ME_AlwaysOnTop_UpdateFrame(record) {
    global ME_Config
    if (!ME_AlwaysOnTop_IsTrackedWindowValid(record)
        || !ME_AlwaysOnTop_IsWindowDisplayable(record.Hwnd)
        || !ME_AlwaysOnTop_GetFrameRectangle(record.Hwnd, rectangle)) {
        ME_AlwaysOnTop_HideFrames(record)
        return false
    }

    thickness := ME_Config.AlwaysOnTop.FrameThickness
    if (rectangle.Width <= thickness * 2 || rectangle.Height <= thickness * 2) {
        ME_AlwaysOnTop_HideFrames(record)
        return false
    }
    if (record.FramesVisible && ME_AlwaysOnTop_RectanglesEqual(record.FrameRectangle, rectangle))
        return true

    if (!ME_AlwaysOnTop_PositionFrames(record, rectangle, thickness)) {
        ME_AlwaysOnTop_HideFrames(record)
        return false
    }
    record.FrameRectangle := rectangle
    record.FramesVisible := true
    return true
}

ME_AlwaysOnTop_PositionFrames(record, rectangle, thickness) {
    placements := []
    for _, frame in record.Frames {
        if (!ME_AlwaysOnTop_IsFrameWindow(frame.Hwnd))
            return false
        if (frame.Side = "Top") {
            x := rectangle.Left, y := rectangle.Top
            width := rectangle.Width, height := thickness
        } else if (frame.Side = "Bottom") {
            x := rectangle.Left, y := rectangle.Bottom - thickness
            width := rectangle.Width, height := thickness
        } else if (frame.Side = "Left") {
            x := rectangle.Left, y := rectangle.Top + thickness
            width := thickness, height := rectangle.Height - thickness * 2
        } else if (frame.Side = "Right") {
            x := rectangle.Right - thickness, y := rectangle.Top + thickness
            width := thickness, height := rectangle.Height - thickness * 2
        } else {
            return false
        }
        placements.Push({Hwnd: frame.Hwnd, X: x, Y: y, Width: width, Height: height})
    }
    frameCount := placements.MaxIndex()
    if (frameCount != 4)
        return false

    deferHandle := DllCall("User32\BeginDeferWindowPos", "Int", frameCount, "Ptr")
    if (!deferHandle)
        return false
    ; SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_NOOWNERZORDER
    flags := 0x0254
    for _, placement in placements {
        nextDeferHandle := DllCall("User32\DeferWindowPos", "Ptr", deferHandle
            , "Ptr", placement.Hwnd, "Ptr", 0, "Int", placement.X, "Int", placement.Y
            , "Int", placement.Width, "Int", placement.Height, "UInt", flags, "Ptr")
        if (!nextDeferHandle)
            return false
        deferHandle := nextDeferHandle
    }
    return DllCall("User32\EndDeferWindowPos", "Ptr", deferHandle, "Int") ? true : false
}

ME_AlwaysOnTop_GetFrameRectangle(hwnd, ByRef rectangle) {
    rectangle := false
    VarSetCapacity(nativeRect, 16, 0)
    hresult := DllCall("Dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9
        , "Ptr", &nativeRect, "UInt", 16, "Int") ; DWMWA_EXTENDED_FRAME_BOUNDS
    if (hresult >= 0) {
        left := NumGet(nativeRect, 0, "Int")
        top := NumGet(nativeRect, 4, "Int")
        right := NumGet(nativeRect, 8, "Int")
        bottom := NumGet(nativeRect, 12, "Int")
        if (right > left && bottom > top) {
            rectangle := {Left: left, Top: top, Right: right, Bottom: bottom
                , Width: right - left, Height: bottom - top}
            return true
        }
    }
    return ME_GetWindowRectangle(hwnd, rectangle)
}

ME_AlwaysOnTop_IsWindowDisplayable(hwnd) {
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        || !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        || DllCall("User32\IsIconic", "Ptr", hwnd, "Int"))
        return false
    cloaked := 0
    hresult := DllCall("Dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14
        , "UIntP", cloaked, "UInt", 4, "Int") ; DWMWA_CLOAKED
    if (hresult >= 0 && cloaked)
        return false
    return true
}

ME_AlwaysOnTop_RectanglesEqual(first, second) {
    if (!IsObject(first) || !IsObject(second))
        return false
    return (first.Left = second.Left && first.Top = second.Top
        && first.Right = second.Right && first.Bottom = second.Bottom)
}

ME_AlwaysOnTop_HideFrames(record) {
    if (!IsObject(record))
        return
    if (record.FramesVisible) {
        for _, frame in record.Frames {
            if (ME_AlwaysOnTop_IsFrameWindow(frame.Hwnd))
                Gui, % frame.Name ":Hide"
        }
    }
    record.FramesVisible := false
    record.FrameRectangle := false
}

ME_AlwaysOnTop_DestroyFrames(record) {
    global ME_State
    if (!IsObject(record))
        return
    state := ME_State.AlwaysOnTop
    for _, frame in record.Frames {
        if (ME_AlwaysOnTop_IsFrameWindow(frame.Hwnd))
            DllCall("User32\RemovePropW", "Ptr", frame.Hwnd
                , "Str", state.IdentityPropertyName, "Ptr")
        if (state.FrameWindows.HasKey(frame.Hwnd))
            state.FrameWindows.Delete(frame.Hwnd)
        Gui, % frame.Name ":Destroy"
    }
    record.Frames := []
    record.FramesVisible := false
    record.FrameRectangle := false
}

ME_AlwaysOnTop_IsFrameWindow(hwnd) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!hwnd || !state.FrameWindows.HasKey(hwnd)
        || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    frameIdentity := state.FrameWindows[hwnd]
    token := DllCall("User32\GetPropW", "Ptr", hwnd
        , "Str", state.IdentityPropertyName, "Ptr")
    return (token = frameIdentity.IdentityToken)
}

ME_AlwaysOnTop_DiscardRecord(hwnd, removeIdentity) {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!state.ManagedWindows.HasKey(hwnd))
        return
    record := state.ManagedWindows[hwnd]
    ME_AlwaysOnTop_DestroyFrames(record)
    if (removeIdentity)
        ME_AlwaysOnTop_RemoveIdentityProperty(record)
    state.ManagedWindows.Delete(hwnd)
    if (state.MoveSizeWindows.HasKey(hwnd))
        state.MoveSizeWindows.Delete(hwnd)
    ME_AlwaysOnTop_RefreshTimerInterval()
    ME_AlwaysOnTop_StopTimerIfIdle()
}

ME_AlwaysOnTop_StartTimer() {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (state.TimerRunning || !state.TimerRegistered)
        return
    timerCallback := state.TimerCallback
    timerIntervalMs := ME_AlwaysOnTop_GetDesiredTimerInterval()
    SetTimer, % timerCallback, % timerIntervalMs
    state.TimerRunning := true
    state.ActiveTimerIntervalMs := timerIntervalMs
}

ME_AlwaysOnTop_GetDesiredTimerInterval() {
    global ME_State
    state := ME_State.AlwaysOnTop
    for hwnd, identityToken in state.MoveSizeWindows {
        if (state.ManagedWindows.HasKey(hwnd)
            && state.ManagedWindows[hwnd].IdentityToken = identityToken)
            return state.MoveSizeTimerIntervalMs
    }
    return state.TimerIntervalMs
}

ME_AlwaysOnTop_RefreshTimerInterval() {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!state.TimerRunning || !state.TimerRegistered)
        return
    timerIntervalMs := ME_AlwaysOnTop_GetDesiredTimerInterval()
    if (state.ActiveTimerIntervalMs = timerIntervalMs)
        return
    timerCallback := state.TimerCallback
    SetTimer, % timerCallback, % timerIntervalMs
    state.ActiveTimerIntervalMs := timerIntervalMs
}

ME_AlwaysOnTop_StopTimerIfIdle() {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (!state.TimerRunning)
        return
    for hwnd, record in state.ManagedWindows
        return
    timerCallback := state.TimerCallback
    SetTimer, % timerCallback, Off
    state.TimerRunning := false
    state.ActiveTimerIntervalMs := 0
}

ME_AlwaysOnTop_Cleanup() {
    global ME_State
    state := ME_State.AlwaysOnTop
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    state.ExplorerFallbackBusy := false

    if (state.HotkeyRegistered) {
        Hotkey, If
        Hotkey, % state.HotkeyName, Off, UseErrorLevel
        state.HotkeyRegistered := false
    }
    ; 共通Cleanupが登録timerをDelete済み。状態側も停止として確定する。
    state.TimerRunning := false
    state.ActiveTimerIntervalMs := 0

    ; callbackを解放する前に、すべてのWinEvent hookを解除する。
    ME_AlwaysOnTop_UninstallWinEventHooks()
    state.MoveSizeWindows := {}

    handles := []
    for hwnd, record in state.ManagedWindows
        handles.Push(hwnd)

    ; 枠をすべて破棄してから、所有しているTopmostだけを解除する。
    for _, hwnd in handles {
        if (state.ManagedWindows.HasKey(hwnd))
            ME_AlwaysOnTop_DestroyFrames(state.ManagedWindows[hwnd])
    }
    for _, hwnd in handles {
        if (!state.ManagedWindows.HasKey(hwnd))
            continue
        record := state.ManagedWindows[hwnd]
        if (ME_AlwaysOnTop_IsTrackedWindowValid(record)) {
            if (ME_AlwaysOnTop_GetTopmost(hwnd, isTopmost) && isTopmost)
                ME_AlwaysOnTop_SetTopmost(hwnd, false)
            ME_AlwaysOnTop_RemoveIdentityProperty(record)
        }
        state.ManagedWindows.Delete(hwnd)
    }

    state.FrameWindows := {}
    state.HotkeyCallback := false
    state.TimerCallback := false
    state.TimerRegistered := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; Open executable folder (Phase 2-2)
; -----------------------------------------------------------------------------

ME_InitializeOpenExeFolder() {
    global ME_Config, ME_State
    state := ME_State.OpenExeFolder
    if (state.Initialized)
        return true
    state.Initialized := true

    if (!ME_Config.EnableFunction.OpenExeFolder || ME_MouseGestureL_IsEditMode())
        return true

    state.HotkeyCallback := Func("ME_OpenExeFolder_OnCtrlLeftButton")
    hotkeyCallback := state.HotkeyCallback
    Hotkey, If
    Hotkey, % state.HotkeyName, % hotkeyCallback, On UseErrorLevel
    if (ErrorLevel) {
        state.HotkeyCallback := false
        return false
    }
    state.HotkeyRegistered := true

    state.PendingTimerCallback := Func("ME_OpenExeFolder_ProcessPending")
    ME_RegisterTimerForCleanup(state.PendingTimerCallback)
    state.PendingTimerRegistered := true
    state.ForegroundTimerCallback := Func("ME_OpenExeFolder_ProcessForegroundPending")
    ME_RegisterTimerForCleanup(state.ForegroundTimerCallback)
    state.ForegroundTimerRegistered := true
    return true
}

ME_OpenExeFolder_OnCtrlLeftButton() {
    global ME_Config, ME_State
    Critical, On
    if (!ME_Config.EnableFunction.OpenExeFolder || !ME_CanRouteMouseInput())
        return
    if (ME_State.SyntheticInputDepth > 0 || !ME_OpenExeFolder_IsCtrlOnly())
        return
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return

    targetHwnd := ME_ResolveTitleBarTarget(screenX, screenY)
    if (!targetHwnd)
        return
    if (!ME_OpenExeFolder_GetExecutablePath(targetHwnd, executablePath
        , processId, threadId)) {
        ME_Debug("OpenExeFolder: executable path unavailable.")
        return
    }
    ME_OpenExeFolder_QueuePending(targetHwnd, processId, threadId, executablePath)
}

ME_OpenExeFolder_IsCtrlOnly() {
    if (!GetKeyState("Ctrl", "P"))
        return false
    if (GetKeyState("Shift", "P") || GetKeyState("Alt", "P")
        || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        return false
    return true
}

ME_OpenExeFolder_GetExecutablePath(hwnd, ByRef executablePath
    , ByRef verifiedProcessId, ByRef verifiedThreadId) {
    executablePath := ""
    verifiedProcessId := 0
    verifiedThreadId := 0
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd)
        || !ME_OpenExeFolder_GetWindowProcess(hwnd, processId, threadId))
        return false

    ; QueryFullProcessImageNameWに必要な最小権限だけで開く。
    processHandle := DllCall("Kernel32\OpenProcess", "UInt", 0x1000
        , "Int", false, "UInt", processId, "Ptr") ; PROCESS_QUERY_LIMITED_INFORMATION
    if (!processHandle)
        return false

    characterCapacity := 32768
    VarSetCapacity(pathBuffer, characterCapacity * 2, 0)
    characterCount := characterCapacity
    querySucceeded := DllCall("Kernel32\QueryFullProcessImageNameW"
        , "Ptr", processHandle, "UInt", 0, "Ptr", &pathBuffer
        , "UIntP", characterCount, "Int")
    DllCall("Kernel32\CloseHandle", "Ptr", processHandle, "Int")

    if (!querySucceeded || characterCount <= 0 || characterCount >= characterCapacity)
        return false
    imagePath := StrGet(&pathBuffer, characterCount, "UTF-16")
    if (imagePath = "")
        return false

    ; 問い合わせ中のHWND破棄・再利用を考慮し、同じroot/PID/TIDか再確認する。
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd)
        || !ME_OpenExeFolder_GetWindowProcess(hwnd, currentProcessId, currentThreadId)
        || currentProcessId != processId || currentThreadId != threadId)
        return false
    attributes := FileExist(imagePath)
    if (!attributes || InStr(attributes, "D"))
        return false
    if (ME_OpenExeFolder_IsAmbiguousHost(hwnd, imagePath))
        return false
    executablePath := imagePath
    verifiedProcessId := processId
    verifiedThreadId := threadId
    return true
}

ME_OpenExeFolder_IsAmbiguousHost(hwnd, imagePath) {
    if (!hwnd || imagePath = ""
        || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return true

    VarSetCapacity(classBuffer, 512, 0)
    classLength := DllCall("User32\GetClassNameW", "Ptr", hwnd
        , "Ptr", &classBuffer, "Int", 256, "Int")
    if (classLength <= 0)
        return true
    className := StrGet(&classBuffer, classLength, "UTF-16")
    SplitPath, imagePath, imageFileName

    ; 既知のApplicationFrameホストだけを拒否し、実アプリ側の探索は行わない。
    if (className = "ApplicationFrameWindow")
        return true
    return (imageFileName = "ApplicationFrameHost.exe") ? true : false
}

ME_OpenExeFolder_GetWindowProcess(hwnd, ByRef processId, ByRef threadId) {
    processId := 0
    threadId := 0
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    threadId := DllCall("User32\GetWindowThreadProcessId", "Ptr", hwnd
        , "UIntP", processId, "UInt")
    return (threadId && processId) ? true : false
}

ME_OpenExeFolder_QueuePending(hwnd, processId, threadId, executablePath) {
    global ME_State
    state := ME_State.OpenExeFolder
    if (state.CleanupStarted || !state.PendingTimerRegistered)
        return false

    ME_OpenExeFolder_CancelForegroundPending()
    ; 新しい有効なMouseDownは未処理requestを置き換え、常に1件だけ保持する。
    state.Pending := {TargetHwnd: hwnd, ProcessId: processId, ThreadId: threadId
        , ExecutablePath: executablePath}
    if (!state.PendingTimerRunning) {
        timerCallback := state.PendingTimerCallback
        timerIntervalMs := state.PendingTimerIntervalMs
        SetTimer, % timerCallback, % timerIntervalMs
        state.PendingTimerRunning := true
    }
    return true
}

ME_OpenExeFolder_ProcessPending() {
    global ME_State
    Critical, On
    state := ME_State.OpenExeFolder
    if (ME_State.CleanupStarted || !ME_State.AcceptingInput || state.CleanupStarted) {
        ME_OpenExeFolder_CancelPending()
        return
    }
    if (!IsObject(state.Pending)) {
        ME_OpenExeFolder_StopPendingTimer()
        return
    }
    if (GetKeyState("LButton", "P"))
        return

    ; 先にstateから取り外し、同じrequestがtimer再入で二度実行されないようにする。
    pending := state.Pending
    state.Pending := false
    ME_OpenExeFolder_StopPendingTimer()
    if (!ME_OpenExeFolder_IsPendingValid(pending))
        return
    if (!ME_OpenExeFolder_SelectInExplorer(pending.ExecutablePath))
        return
    ME_OpenExeFolder_StartForegroundPending(pending.ExecutablePath)
}

ME_OpenExeFolder_IsPendingValid(pending) {
    if (!IsObject(pending) || !pending.TargetHwnd || !pending.ProcessId
        || !pending.ThreadId || pending.ExecutablePath = "")
        return false
    if (!ME_OpenExeFolder_GetExecutablePath(pending.TargetHwnd, currentPath
        , currentProcessId, currentThreadId))
        return false
    return (currentProcessId = pending.ProcessId && currentThreadId = pending.ThreadId
        && currentPath = pending.ExecutablePath)
}

ME_OpenExeFolder_StopPendingTimer() {
    global ME_State
    state := ME_State.OpenExeFolder
    if (!state.PendingTimerRunning)
        return
    timerCallback := state.PendingTimerCallback
    SetTimer, % timerCallback, Off
    state.PendingTimerRunning := false
}

ME_OpenExeFolder_CancelPending() {
    global ME_State
    ME_State.OpenExeFolder.Pending := false
    ME_OpenExeFolder_StopPendingTimer()
}

ME_OpenExeFolder_SelectInExplorer(executablePath) {
    if (executablePath = "")
        return false
    attributes := FileExist(executablePath)
    if (!attributes || InStr(attributes, "D"))
        return false

    initializeResult := DllCall("Ole32\CoInitializeEx", "Ptr", 0
        , "UInt", 0x2, "Int") ; COINIT_APARTMENTTHREADED
    if (initializeResult != 0 && initializeResult != 1) ; S_OK / S_FALSE
        return false

    ; absoluteItemPidlはこの関数が所有し、全経路でCoTaskMemFreeする。
    absoluteItemPidl := DllCall("Shell32\ILCreateFromPathW"
        , "WStr", executablePath, "Ptr")
    parentFolderPidl := 0
    childPidl := 0
    shellCalled := false
    hresult := 0

    if (absoluteItemPidl) {
        ; childPidlはabsoluteItemPidl内部を指すborrowed pointer。単体ではfreeしない。
        childPidl := DllCall("Shell32\ILFindLastID", "Ptr", absoluteItemPidl, "Ptr")
        if (childPidl && NumGet(childPidl + 0, 0, "UShort") != 0) {
            ; parentFolderPidlはabsolute PIDLの独立したcloneで、この関数が所有する。
            parentFolderPidl := DllCall("Shell32\ILClone"
                , "Ptr", absoluteItemPidl, "Ptr")
            if (parentFolderPidl
                && DllCall("Shell32\ILRemoveLastID", "Ptr", parentFolderPidl, "Int")) {
                ; 配列bufferはこの同期呼出し中だけ有効。中のborrowed pointerもfreeしない。
                VarSetCapacity(childPidlArray, A_PtrSize, 0)
                NumPut(childPidl, childPidlArray, 0, "Ptr")
                shellCalled := true
                hresult := DllCall("Shell32\SHOpenFolderAndSelectItems"
                    , "Ptr", parentFolderPidl, "UInt", 1, "Ptr", &childPidlArray
                    , "UInt", 0, "Int")
            }
        }
    }

    ; owned PIDLだけを解放する。childPidlとchildPidlArrayは解放対象ではない。
    if (parentFolderPidl)
        DllCall("Ole32\CoTaskMemFree", "Ptr", parentFolderPidl)
    if (absoluteItemPidl)
        DllCall("Ole32\CoTaskMemFree", "Ptr", absoluteItemPidl)
    DllCall("Ole32\CoUninitialize")

    if (!shellCalled) {
        ME_Debug("OpenExeFolder: explicit parent/child PIDL construction failed.")
        return false
    }
    if (hresult != 0) {
        ME_Debug("OpenExeFolder: SHOpenFolderAndSelectItems HRESULT="
            . Format("0x{:08X}", hresult & 0xFFFFFFFF))
        return false
    }
    return true
}

ME_OpenExeFolder_StartForegroundPending(executablePath) {
    global ME_State
    state := ME_State.OpenExeFolder
    if (state.CleanupStarted || !state.ForegroundTimerRegistered
        || executablePath = "")
        return false

    SplitPath, executablePath, targetName, targetFolder
    if (targetName = "" || targetFolder = "")
        return false

    state.ForegroundPending := {ExecutablePath: executablePath
        , FolderPath: targetFolder, StartTick: A_TickCount}
    if (!state.ForegroundTimerRunning) {
        timerCallback := state.ForegroundTimerCallback
        timerIntervalMs := state.ForegroundTimerIntervalMs
        SetTimer, % timerCallback, % timerIntervalMs
        state.ForegroundTimerRunning := true
    }
    return true
}

ME_OpenExeFolder_ProcessForegroundPending() {
    global ME_State
    Critical, On
    state := ME_State.OpenExeFolder
    if (ME_State.CleanupStarted || !ME_State.AcceptingInput || state.CleanupStarted) {
        ME_OpenExeFolder_CancelForegroundPending()
        return
    }
    if (!IsObject(state.ForegroundPending)) {
        ME_OpenExeFolder_StopForegroundTimer()
        return
    }

    pending := state.ForegroundPending
    elapsedMs := (A_TickCount - pending.StartTick) & 0xFFFFFFFF
    if (elapsedMs > state.ForegroundTimeoutMs) {
        ME_OpenExeFolder_CancelForegroundPending()
        return
    }

    candidateCount := ME_OpenExeFolder_FindMatchingExplorerWindows(pending
        , candidateHwnd)
    if (candidateCount = 0)
        return

    ; 1件を確認した時点、または2件以上で曖昧になった時点で探索を終了する。
    state.ForegroundPending := false
    ME_OpenExeFolder_StopForegroundTimer()
    if (candidateCount != 1 || !candidateHwnd
        || !DllCall("User32\IsWindow", "Ptr", candidateHwnd, "Int"))
        return

    ; 列挙後の破棄・HWND再利用や選択変更を避け、foreground操作直前にも一意性を再確認する。
    verificationCount := ME_OpenExeFolder_FindMatchingExplorerWindows(pending
        , verificationHwnd)
    if (verificationCount != 1 || verificationHwnd != candidateHwnd)
        return

    ME_Debug("OpenExeFolder: matching Explorer found.")
    if (DllCall("User32\IsIconic", "Ptr", candidateHwnd, "Int"))
        DllCall("User32\ShowWindow", "Ptr", candidateHwnd, "Int", 9, "Int") ; SW_RESTORE
    foregroundResult := DllCall("User32\SetForegroundWindow", "Ptr", candidateHwnd, "Int")
    if (foregroundResult) {
        ME_Debug("OpenExeFolder: SetForegroundWindow succeeded.")
        return
    }
    ME_Debug("OpenExeFolder: SetForegroundWindow was refused by Windows.")
    ; Windowsが拒否した場合はここで終了する。前面化はbest-effortである。
}

ME_OpenExeFolder_FindMatchingExplorerWindows(pending, ByRef candidateHwnd) {
    candidateHwnd := 0
    if (!IsObject(pending) || pending.ExecutablePath = "" || pending.FolderPath = "")
        return 0

    try shellApplication := ComObjCreate("Shell.Application")
    catch createError
        return 0
    try shellWindows := shellApplication.Windows()
    catch windowsError
        return 0
    if (!IsObject(shellWindows))
        return 0
    try windowCount := shellWindows.Count + 0
    catch countError
        return 0

    matches := {}
    matchCount := 0
    Loop, % windowCount {
        shellIndex := A_Index - 1
        try shellWindow := shellWindows.Item(shellIndex)
        catch itemError
            continue
        if (!IsObject(shellWindow)
            || !ME_OpenExeFolder_IsMatchingExplorerWindow(shellWindow, pending
                , explorerHwnd))
            continue
        if (matches.HasKey(explorerHwnd))
            continue
        matches[explorerHwnd] := true
        matchCount++
        candidateHwnd := explorerHwnd
        if (matchCount > 1)
            return matchCount
    }
    return matchCount
}

ME_OpenExeFolder_IsMatchingExplorerWindow(shellWindow, pending
    , ByRef explorerHwnd) {
    explorerHwnd := 0
    try {
        candidateHwnd := shellWindow.HWND + 0
        document := shellWindow.Document
        displayedFolder := document.Folder.Self.Path
        selectedItems := document.SelectedItems()
        selectedCount := selectedItems.Count + 0
    } catch shellWindowError {
        return false
    }
    if (!candidateHwnd || !DllCall("User32\IsWindow", "Ptr", candidateHwnd, "Int")
        || displayedFolder != pending.FolderPath || selectedCount <= 0)
        return false

    selectedTarget := false
    Loop, % selectedCount {
        selectedIndex := A_Index - 1
        try selectedItem := selectedItems.Item(selectedIndex)
        catch selectedItemError
            continue
        if (!IsObject(selectedItem))
            continue
        try selectedPath := selectedItem.Path
        catch selectedPathError
            continue
        if (selectedPath = pending.ExecutablePath) {
            selectedTarget := true
            break
        }
    }
    if (!selectedTarget || !ME_OpenExeFolder_IsExplorerProcessWindow(candidateHwnd))
        return false
    explorerHwnd := candidateHwnd
    return true
}

ME_OpenExeFolder_IsExplorerProcessWindow(hwnd) {
    if (!ME_OpenExeFolder_GetExecutablePath(hwnd, imagePath, processId, threadId))
        return false
    SplitPath, imagePath, imageFileName
    return (imageFileName = "explorer.exe") ? true : false
}

ME_OpenExeFolder_StopForegroundTimer() {
    global ME_State
    state := ME_State.OpenExeFolder
    if (!state.ForegroundTimerRunning)
        return
    timerCallback := state.ForegroundTimerCallback
    SetTimer, % timerCallback, Off
    state.ForegroundTimerRunning := false
}

ME_OpenExeFolder_CancelForegroundPending() {
    global ME_State
    ME_State.OpenExeFolder.ForegroundPending := false
    ME_OpenExeFolder_StopForegroundTimer()
}

ME_OpenExeFolder_Cleanup() {
    global ME_State
    state := ME_State.OpenExeFolder
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    if (state.HotkeyRegistered) {
        Hotkey, If
        Hotkey, % state.HotkeyName, Off, UseErrorLevel
        state.HotkeyRegistered := false
    }
    ; 共通Cleanupが両timerをDelete済み。requestと残りの参照を破棄する。
    state.PendingTimerRunning := false
    state.ForegroundTimerRunning := false
    state.Pending := false
    state.ForegroundPending := false
    state.HotkeyCallback := false
    state.PendingTimerCallback := false
    state.PendingTimerRegistered := false
    state.ForegroundTimerCallback := false
    state.ForegroundTimerRegistered := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; Move disabled window (Phase 2-3)
; -----------------------------------------------------------------------------

ME_InitializeMoveDisabledWindow() {
    global ME_Config, ME_State
    state := ME_State.MoveDisabledWindow
    if (state.Initialized)
        return true
    state.Initialized := true

    if (!ME_Config.EnableFunction.MoveDisabledWindow || ME_MouseGestureL_IsEditMode())
        return true

    state.HotkeyCallback := Func("ME_MoveDisabledWindow_OnLeftButton")
    hotkeyCallback := state.HotkeyCallback
    Hotkey, If
    Hotkey, % state.HotkeyName, % hotkeyCallback, On UseErrorLevel
    if (ErrorLevel) {
        state.HotkeyCallback := false
        return false
    }
    state.HotkeyRegistered := true

    state.TimerCallback := Func("ME_MoveDisabledWindow_ProcessDrag")
    ME_RegisterTimerForCleanup(state.TimerCallback)
    state.TimerRegistered := true
    return true
}

ME_MoveDisabledWindow_OnLeftButton() {
    global ME_Config, ME_State
    Critical, On
    state := ME_State.MoveDisabledWindow
    if (!ME_Config.EnableFunction.MoveDisabledWindow || !ME_CanRouteMouseInput()
        || state.CleanupStarted || state.TimerRunning || IsObject(state.Drag))
        return
    if (ME_State.SyntheticInputDepth > 0 || !GetKeyState("LButton", "P"))
        return
    ; modifier付き入力は既存のShift/Ctrl機能とOSへ任せる。
    if (GetKeyState("Shift", "P") || GetKeyState("Ctrl", "P")
        || GetKeyState("Alt", "P") || GetKeyState("LWin", "P")
        || GetKeyState("RWin", "P"))
        return

    drag := ME_MoveDisabledWindow_ResolveTarget()
    if (!IsObject(drag))
        return
    if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0
        || !GetKeyState("LButton", "P"))
        return

    state.Drag := drag
    if (!ME_MoveDisabledWindow_StartDrag())
        state.Drag := false
}

ME_MoveDisabledWindow_ResolveTarget() {
    ; WindowFromPointを使う共通resolverとは分離し、disabled-awareなMouseGetPosを使う。
    CoordMode, Mouse, Screen
    MouseGetPos, screenX, screenY, pointHwnd
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false

    targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!targetHwnd
        || DllCall("User32\GetAncestor", "Ptr", targetHwnd, "UInt", 2, "Ptr") != targetHwnd
        || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return false
    if (!ME_AlwaysOnTop_GetWindowStyle(targetHwnd, -16, style)
        || !(style & 0x08000000)) ; WS_DISABLED
        return false
    if (!ME_GetWindowRectangle(targetHwnd, rectangle)
        || screenX < rectangle.Left || screenX >= rectangle.Right
        || screenY < rectangle.Top || screenY >= rectangle.Bottom)
        return false

    hitTest := ME_SendNcHitTest(targetHwnd, screenX, screenY, 50)
    if (!hitTest.Succeeded || hitTest.Result != 2) ; HTCAPTION
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className))
        return false

    return {TargetHwnd: targetHwnd, ProcessId: processId, ThreadId: threadId
        , ClassName: className, LastMouseX: screenX, LastMouseY: screenY}
}

ME_MoveDisabledWindow_IsTargetValid(drag) {
    if (!IsObject(drag) || !drag.TargetHwnd)
        return false
    targetHwnd := drag.TargetHwnd
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || DllCall("User32\GetAncestor", "Ptr", targetHwnd, "UInt", 2, "Ptr") != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != drag.ProcessId || threadId != drag.ThreadId
        || !(className == drag.ClassName))
        return false
    if (!ME_AlwaysOnTop_GetWindowStyle(targetHwnd, -16, style)
        || !(style & 0x08000000)) ; WS_DISABLED
        return false
    return true
}

ME_MoveDisabledWindow_StartDrag() {
    global ME_State
    state := ME_State.MoveDisabledWindow
    if (state.CleanupStarted || !state.TimerRegistered || !IsObject(state.Drag))
        return false
    if (state.TimerRunning)
        return true
    timerCallback := state.TimerCallback
    timerIntervalMs := state.TimerIntervalMs
    SetTimer, % timerCallback, % timerIntervalMs
    state.TimerRunning := true
    return true
}

ME_MoveDisabledWindow_ProcessDrag() {
    global ME_State
    Critical, On
    state := ME_State.MoveDisabledWindow
    if (!GetKeyState("LButton", "P")) {
        ME_MoveDisabledWindow_StopDrag()
        return
    }
    if (!state.TimerRunning || !IsObject(state.Drag)
        || !ME_State.AcceptingInput || ME_State.CleanupStarted || state.CleanupStarted
        || !ME_MouseGestureL_AllowsInput() || ME_State.SyntheticInputDepth > 0) {
        ME_MoveDisabledWindow_StopDrag()
        return
    }

    drag := state.Drag
    if (!ME_MoveDisabledWindow_IsTargetValid(drag)
        || !ME_GetCursorScreenPoint(currentMouseX, currentMouseY)) {
        ME_MoveDisabledWindow_StopDrag()
        return
    }
    deltaX := currentMouseX - drag.LastMouseX
    deltaY := currentMouseY - drag.LastMouseY
    if (deltaX = 0 && deltaY = 0)
        return
    if (!ME_GetWindowRectangle(drag.TargetHwnd, rectangle)) {
        ME_MoveDisabledWindow_StopDrag()
        return
    }

    newX := rectangle.Left + deltaX
    newY := rectangle.Top + deltaY
    ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER
    flags := 0x0215
    moved := DllCall("User32\SetWindowPos", "Ptr", drag.TargetHwnd, "Ptr", 0
        , "Int", newX, "Int", newY, "Int", 0, "Int", 0, "UInt", flags, "Int")
    if (!moved) {
        ME_MoveDisabledWindow_StopDrag()
        return
    }
    drag.LastMouseX := currentMouseX
    drag.LastMouseY := currentMouseY
}

ME_MoveDisabledWindow_StopDrag() {
    global ME_State
    state := ME_State.MoveDisabledWindow
    if (state.TimerRunning && IsObject(state.TimerCallback)) {
        timerCallback := state.TimerCallback
        SetTimer, % timerCallback, Off
    }
    state.TimerRunning := false
    state.Drag := false
}

ME_MoveDisabledWindow_Cleanup() {
    global ME_State
    state := ME_State.MoveDisabledWindow
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    if (state.HotkeyRegistered) {
        Hotkey, If
        Hotkey, % state.HotkeyName, Off, UseErrorLevel
        state.HotkeyRegistered := false
    }
    state.TimerRunning := false
    state.Drag := false
    state.HotkeyCallback := false
    state.TimerCallback := false
    state.TimerRegistered := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; TabSwitch (Phase 2-4A / 2-4B / 2-4C: browsers / XAML / classic tabs)
; -----------------------------------------------------------------------------

ME_InitializeTabSwitch() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    if (state.Initialized)
        return true
    state.Initialized := true

    if (!ME_Config.EnableFunction.TabSwitch || ME_MouseGestureL_IsEditMode())
        return true
    if (!ME_Config.TabSwitch.Firefox && !ME_Config.TabSwitch.Chrome
        && !ME_Config.TabSwitch.Edge && !ME_Config.TabSwitch.Notepad
        && !ME_Config.TabSwitch.Explorer && !ME_Config.TabSwitch.SysTabControl32
        && !ME_Config.TabSpecial.MaxIndex())
        return true
    if (!ME_InitializeWheelInput()) {
        state.Initialized := false
        return false
    }
    return true
}

ME_TabSwitch_PrepareTarget() {
    global ME_Config, ME_State
    ME_State.TabSwitch.Candidate := false

    if (GetKeyState("LButton", "P"))
        return false

    if (ME_Config.TabIgnore.MaxIndex()) {
        if (ME_TabSwitch_ShouldIgnoreCurrentTarget())
            return false
    }
    if (ME_Config.TabSpecial.MaxIndex()) {
        if (ME_TabSwitch_PrepareSpecialTarget())
            return true
    }
    if (ME_TabSwitch_PrepareBrowserTarget())
        return true
    if (ME_TabSwitch_PrepareExplorerTarget())
        return true
    if (ME_TabSwitch_PrepareNotepadTarget())
        return true
    if (ME_TabSwitch_PrepareSysTabControlTarget())
        return true
    ME_State.TabSwitch.Candidate := false
    return false
}

ME_TabSwitch_PrepareSpecialTarget() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    state.Candidate := false
    try {
        if (!state.Initialized || state.CleanupStarted
            || !ME_Config.EnableFunction.TabSwitch || !ME_Config.TabSpecial.MaxIndex()
            || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth != 0)
            return false
        if (!ME_GetCursorScreenPoint(screenX, screenY))
            return false
        pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
        if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
            return false
        targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
        if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
            || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
            return false
        if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
            || !ME_TabSwitch_GetWindowTitle(targetHwnd, titleText)
            || !ME_ScreenToWindowPoint(targetHwnd, screenX, screenY, windowX, windowY))
            return false

        ; parserが作成したRuleN昇順。最初に一致したRuleのscalarだけを保存する。
        for _, rule in ME_Config.TabSpecial {
            if (!ME_TabSwitch_MatchesWindowRule(rule, className, titleText)
                || !ME_TabSwitch_IsPointInSpecialRule(rule, windowX, windowY))
                continue
            candidate := {TargetHwnd: targetHwnd, ProcessId: processId
                , ThreadId: threadId, ClassName: className, Adapter: "TabSpecial"
                , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount
                , SpecialRuleNumber: rule.Number, SpecialRuleClass: rule.Class
                , SpecialRuleTitle: rule.Title, SpecialRuleLeft: rule.Left
                , SpecialRuleTop: rule.Top, SpecialRuleWidth: rule.Width
                , SpecialRuleHeight: rule.Height}
            if (!ME_TabSwitch_IsSpecialCandidateValid(candidate))
                return false
            candidate.Tick := A_TickCount
            state.Candidate := candidate
            return true
        }
        return false
    } catch error {
        return false
    }
}

ME_TabSwitch_IsPointInSpecialRule(rule, windowX, windowY) {
    if (!IsObject(rule))
        return false
    for _, field in ["Left", "Top", "Width", "Height"] {
        if (!ME_IsIntegerString(rule[field]))
            return false
    }
    if (rule.Width <= 0 || rule.Height <= 0)
        return false
    return (windowX >= rule.Left && windowX < rule.Left + rule.Width
        && windowY >= rule.Top && windowY < rule.Top + rule.Height) ? true : false
}

ME_TabSwitch_IsSpecialCandidateValid(candidate) {
    global ME_Config, ME_State
    try {
        if (!IsObject(candidate) || !(candidate.Adapter == "TabSpecial")
            || !ME_State.TabSwitch.Initialized || ME_State.TabSwitch.CleanupStarted
            || !ME_Config.EnableFunction.TabSwitch || !ME_Config.TabSpecial.MaxIndex()
            || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth != 0)
            return false
        ; CandidateにはRule objectを保持せず、検証時だけscalarから復元する。
        rule := {}
        fields := ["Number", "Class", "Title", "Left", "Top", "Width", "Height"]
        for _, field in fields {
            keyName := "SpecialRule" . field
            if (!candidate.HasKey(keyName) || IsObject(candidate[keyName]))
                return false
            rule[field] := candidate[keyName]
        }
        if (!ME_IsIntegerString(rule.Number) || rule.Number < 1)
            return false
        ruleFound := false
        for _, currentRule in ME_Config.TabSpecial {
            if (currentRule.Number != rule.Number)
                continue
            for _, field in fields {
                if (!(currentRule[field] == rule[field]))
                    return false
            }
            ruleFound := true
            break
        }
        if (!ruleFound)
            return false

        targetHwnd := candidate.TargetHwnd
        if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
            || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd
            || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
            || processId != candidate.ProcessId || threadId != candidate.ThreadId
            || !(className == candidate.ClassName))
            return false
        if (!ME_TabSwitch_GetWindowTitle(targetHwnd, titleText)
            || !ME_TabSwitch_MatchesWindowRule(rule, className, titleText))
            return false
        if (!ME_GetCursorScreenPoint(screenX, screenY))
            return false
        pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
        if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd)
            || DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr") != targetHwnd)
            return false
        if (!ME_ScreenToWindowPoint(targetHwnd, screenX, screenY, windowX, windowY)
            || !ME_TabSwitch_IsPointInSpecialRule(rule, windowX, windowY))
            return false
        if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth != 0
            || ME_State.TabSwitch.CleanupStarted
            || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
            || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd
            || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
                , currentThreadId, currentClassName)
            || currentProcessId != processId || currentThreadId != threadId
            || !(currentClassName == className))
            return false
        return true
    } catch error {
        return false
    }
}

ME_TabSwitch_ShouldIgnoreCurrentTarget(expectedCandidate := false) {
    global ME_Config
    ; Ruleがある場合だけ呼ぶ。評価不能もtrueとしてTabSwitchを抑止する。
    try {
        if (!ME_GetCursorScreenPoint(screenX, screenY))
            return true
        pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
        if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
            return true
        targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
        if (IsObject(expectedCandidate) && targetHwnd != expectedCandidate.TargetHwnd)
            return true
        if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
            return true
        if (DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
            return true
        if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className))
            return true
        if (IsObject(expectedCandidate)
            && (processId != expectedCandidate.ProcessId
                || threadId != expectedCandidate.ThreadId
                || !(className == expectedCandidate.ClassName)))
            return true
        if (!ME_TabSwitch_GetWindowTitle(targetHwnd, titleText))
            return true

        ; title取得中の破棄・置換・foreground変更は一致なしとして通さない。
        if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
            || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd
            || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
                , currentThreadId, currentClassName)
            || currentProcessId != processId || currentThreadId != threadId
            || !(currentClassName == className))
            return true

        ; parserが作成したRuleN昇順をそのまま使用する。
        for _, rule in ME_Config.TabIgnore {
            if (ME_TabSwitch_MatchesWindowRule(rule, className, titleText))
                return true
        }
        return false
    } catch error {
        return true
    }
}

ME_TabSwitch_MatchesWindowRule(rule, className, titleText) {
    if (!IsObject(rule) || (rule.Class = "" && rule.Title = ""))
        return false
    if (rule.Class != "" && !(ME_Lower(className) == ME_Lower(rule.Class)))
        return false
    if (rule.Title != "" && !InStr(ME_Lower(titleText), ME_Lower(rule.Title), true))
        return false
    return true
}

ME_TabSwitch_GetWindowTitle(hwnd, ByRef titleText) {
    titleText := ""
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    ; 空titleの0とAPI失敗の0を区別する。
    DllCall("Kernel32\SetLastError", "UInt", 0)
    titleLength := DllCall("User32\GetWindowTextLengthW", "Ptr", hwnd, "Int")
    if (titleLength < 0 || (titleLength = 0 && A_LastError))
        return false
    bufferChars := titleLength + 2
    if (VarSetCapacity(titleBuffer, bufferChars * 2, 0) < bufferChars * 2)
        return false
    DllCall("Kernel32\SetLastError", "UInt", 0)
    copiedLength := DllCall("User32\GetWindowTextW", "Ptr", hwnd
        , "Ptr", &titleBuffer, "Int", bufferChars, "Int")
    if (copiedLength < 0 || (copiedLength = 0 && A_LastError)
        || copiedLength >= bufferChars - 1)
        return false
    if (!DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    if (copiedLength > 0)
        titleText := StrGet(&titleBuffer, copiedLength, "UTF-16")
    return true
}

ME_TabSwitch_PrepareBrowserTarget() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    state.Candidate := false

    if (!state.Initialized || state.CleanupStarted
        || !ME_Config.EnableFunction.TabSwitch || !ME_CanRouteMouseInput()
        || ME_State.SyntheticInputDepth > 0)
        return false
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false

    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false
    targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return false
    foregroundHwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd || foregroundHwnd != targetHwnd)
        return false

    if (!ME_OpenExeFolder_GetExecutablePath(targetHwnd, executablePath
        , verifiedProcessId, verifiedThreadId))
        return false
    SplitPath, executablePath, executableName
    adapter := ME_TabSwitch_GetBrowserAdapter(executableName)
    if (adapter = "" || !ME_TabSwitch_IsAdapterEnabled(adapter))
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != verifiedProcessId || threadId != verifiedThreadId)
        return false

    try {
        isBrowserTab := ME_TabSwitch_IsBrowserTabAtPoint(adapter, screenX, screenY)
    } catch error {
        isBrowserTab := false
    }
    if (!isBrowserTab)
        return false

    ; UIA問い合わせ中の切替・破棄を考慮し、scalar候補の保存直前に再確認する。
    if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0
        || state.CleanupStarted || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
        return false
    currentPointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentPointHwnd || ME_AlwaysOnTop_IsFrameWindow(currentPointHwnd))
        return false
    currentRootHwnd := DllCall("User32\GetAncestor", "Ptr", currentPointHwnd
        , "UInt", 2, "Ptr")
    if (currentRootHwnd != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
        , currentThreadId, currentClassName)
        || currentProcessId != processId || currentThreadId != threadId
        || !(currentClassName == className))
        return false

    state.Candidate := {TargetHwnd: targetHwnd, ProcessId: processId
        , ThreadId: threadId, ClassName: className, Adapter: adapter
        , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount}
    return true
}

ME_TabSwitch_PrepareExplorerTarget() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    state.Candidate := false

    if (!state.Initialized || state.CleanupStarted
        || !ME_Config.EnableFunction.TabSwitch || !ME_Config.TabSwitch.Explorer
        || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0)
        return false
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false

    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false
    targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return false
    foregroundHwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd || foregroundHwnd != targetHwnd)
        return false

    ; 高コストのpath/UIA確認より先にExplorerのtop-level候補だけへ絞る。
    WinGet, processName, ProcessName, ahk_id %targetHwnd%
    if (processName != "explorer.exe")
        return false
    WinGetClass, precheckClassName, ahk_id %targetHwnd%
    if (!(precheckClassName == "CabinetWClass"))
        return false

    if (!ME_OpenExeFolder_GetExecutablePath(targetHwnd, executablePath
        , verifiedProcessId, verifiedThreadId))
        return false
    SplitPath, executablePath, executableName
    if (executableName != "explorer.exe")
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != verifiedProcessId || threadId != verifiedThreadId
        || !(className == "CabinetWClass"))
        return false

    try {
        isExplorerTab := ME_TabSwitch_IsExplorerTabAtPoint(screenX, screenY)
    } catch error {
        isExplorerTab := false
    }
    if (!isExplorerTab)
        return false

    ; UIA問い合わせ中の対象変更を排除してからscalar候補だけを保存する。
    if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0
        || state.CleanupStarted || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
        return false
    currentPointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentPointHwnd || ME_AlwaysOnTop_IsFrameWindow(currentPointHwnd))
        return false
    currentRootHwnd := DllCall("User32\GetAncestor", "Ptr", currentPointHwnd
        , "UInt", 2, "Ptr")
    if (currentRootHwnd != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
        , currentThreadId, currentClassName)
        || currentProcessId != processId || currentThreadId != threadId
        || !(currentClassName == className))
        return false

    state.Candidate := {TargetHwnd: targetHwnd, ProcessId: processId
        , ThreadId: threadId, ClassName: className, Adapter: "Explorer"
        , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount}
    return true
}

ME_TabSwitch_PrepareNotepadTarget() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    state.Candidate := false

    if (!state.Initialized || state.CleanupStarted
        || !ME_Config.EnableFunction.TabSwitch || !ME_Config.TabSwitch.Notepad
        || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0)
        return false
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false

    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false
    targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return false
    foregroundHwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd || foregroundHwnd != targetHwnd)
        return false

    if (!ME_OpenExeFolder_GetExecutablePath(targetHwnd, executablePath
        , verifiedProcessId, verifiedThreadId))
        return false
    SplitPath, executablePath, executableName
    if (executableName != "Notepad.exe")
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != verifiedProcessId || threadId != verifiedThreadId
        || !(className == "Notepad"))
        return false

    try {
        isNotepadTab := ME_TabSwitch_IsNotepadTabAtPoint(screenX, screenY)
    } catch error {
        isNotepadTab := false
    }
    if (!isNotepadTab)
        return false

    ; UIA問い合わせ中に対象が変化していない場合だけscalar候補を保存する。
    if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0
        || state.CleanupStarted || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
        return false
    currentPointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentPointHwnd || ME_AlwaysOnTop_IsFrameWindow(currentPointHwnd))
        return false
    currentRootHwnd := DllCall("User32\GetAncestor", "Ptr", currentPointHwnd
        , "UInt", 2, "Ptr")
    if (currentRootHwnd != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
        , currentThreadId, currentClassName)
        || currentProcessId != processId || currentThreadId != threadId
        || !(currentClassName == className))
        return false

    state.Candidate := {TargetHwnd: targetHwnd, ProcessId: processId
        , ThreadId: threadId, ClassName: className, Adapter: "Notepad"
        , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount}
    return true
}

ME_TabSwitch_PrepareSysTabControlTarget() {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    state.Candidate := false

    if (!state.Initialized || state.CleanupStarted
        || !ME_Config.EnableFunction.TabSwitch || !ME_Config.TabSwitch.SysTabControl32
        || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0)
        return false
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false

    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false

    controlHwnd := ME_TabSwitch_FindSysTabControlAncestor(pointHwnd)
    if (!controlHwnd || !ME_TabSwitch_IsSysTabControlWindow(controlHwnd)
        || !ME_TabSwitch_IsPointInsideWindow(controlHwnd, screenX, screenY))
        return false

    targetHwnd := DllCall("User32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr")
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd))
        return false
    if (DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className))
        return false

    isTab := false
    try {
        isTab := ME_TabSwitch_IsSysTabAtPointUIA(controlHwnd, screenX, screenY)
    } catch error {
        isTab := false
    }
    if (!isTab) {
        try {
            isTab := ME_TabSwitch_IsSysTabAtPointMSAA(controlHwnd, screenX, screenY)
        } catch error {
            isTab := false
        }
    }
    if (!isTab)
        return false

    ; accessibility判定後もroot/control/cursorの同一性をすべて確認する。
    if (!ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth > 0
        || state.CleanupStarted || !ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd
        || !ME_TabSwitch_IsSysTabControlWindow(controlHwnd))
        return false
    currentPointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!currentPointHwnd || ME_AlwaysOnTop_IsFrameWindow(currentPointHwnd))
        return false
    currentControlHwnd := ME_TabSwitch_FindSysTabControlAncestor(currentPointHwnd)
    if (currentControlHwnd != controlHwnd
        || DllCall("User32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") != targetHwnd)
        return false
    if (!ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, currentProcessId
        , currentThreadId, currentClassName)
        || currentProcessId != processId || currentThreadId != threadId
        || !(currentClassName == className))
        return false

    state.Candidate := {TargetHwnd: targetHwnd, ControlHwnd: controlHwnd
        , ProcessId: processId, ThreadId: threadId, ClassName: className
        , Adapter: "SysTabControl32", ScreenX: screenX, ScreenY: screenY
        , Tick: A_TickCount}
    return true
}

ME_TabSwitch_GetBrowserAdapter(executableName) {
    if (executableName = "firefox.exe")
        return "Firefox"
    if (executableName = "chrome.exe")
        return "Chrome"
    if (executableName = "msedge.exe")
        return "Edge"
    return ""
}

ME_TabSwitch_IsAdapterEnabled(adapter) {
    global ME_Config
    if (!ME_Config.EnableFunction.TabSwitch)
        return false
    if (adapter == "Firefox")
        return ME_Config.TabSwitch.Firefox ? true : false
    if (adapter == "Chrome")
        return ME_Config.TabSwitch.Chrome ? true : false
    if (adapter == "Edge")
        return ME_Config.TabSwitch.Edge ? true : false
    if (adapter == "Notepad")
        return ME_Config.TabSwitch.Notepad ? true : false
    if (adapter == "Explorer")
        return ME_Config.TabSwitch.Explorer ? true : false
    if (adapter == "SysTabControl32")
        return ME_Config.TabSwitch.SysTabControl32 ? true : false
    if (adapter == "TabSpecial")
        return ME_Config.TabSpecial.MaxIndex() ? true : false
    return false
}

ME_TabSwitch_IsBrowserTabAtPoint(adapter, screenX, screenY) {
    global ME_State
    currentPtr := 0
    nextPtr := 0
    tabItemFound := false
    depth := 0
    maxDepth := ME_State.TabSwitch.AncestryMaxDepth

    try {
        ; 戻り値は呼出元owned。共有UIAのRawViewWalker自体は借用し解放しない。
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY)
        if (!currentPtr)
            return false

        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType))
                return false

            if (!tabItemFound) {
                if (controlType = 50019) {
                    if (!ME_UIA_GetProperty(currentPtr, 30012, className)
                        || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                        return false
                    if (ME_TabSwitch_MatchesTabItem(adapter, controlType
                        , className, frameworkId))
                        tabItemFound := true
                }
            } else if (controlType = 50018) {
                if (!ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (adapter == "Firefox") {
                    if (!ME_UIA_GetProperty(currentPtr, 30011, automationId))
                        return false
                    if (automationId == "tabbrowser-tabs" && frameworkId == "Gecko")
                        return true
                } else {
                    if (!ME_UIA_GetProperty(currentPtr, 30012, className))
                        return false
                    if (ME_TabSwitch_MatchesTabContainer(adapter, controlType
                        , className, frameworkId))
                        return true
                }
            }

            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } finally {
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_TabSwitch_IsNotepadTabAtPoint(screenX, screenY) {
    global ME_State
    currentPtr := 0
    nextPtr := 0
    stage := 0
    depth := 0
    maxDepth := ME_State.TabSwitch.NotepadAncestryMaxDepth

    try {
        ; element/parentは呼出元owned。共有RawViewWalkerはservice所有のまま借用する。
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY)
        if (!currentPtr)
            return false

        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType))
                return false

            if (stage = 0 && controlType = 50019) {
                if (!ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (className == "ListViewItem" && frameworkId == "XAML")
                    stage := 1
            } else if (stage = 1 && controlType = 50008) {
                if (!ME_UIA_GetProperty(currentPtr, 30011, automationId)
                    || !ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (automationId == "TabListView" && className == "ListView"
                    && frameworkId == "XAML")
                    stage := 2
            } else if (stage = 2 && controlType = 50018) {
                if (!ME_UIA_GetProperty(currentPtr, 30011, automationId)
                    || !ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (automationId == "Tabs"
                    && className == "Microsoft.UI.Xaml.Controls.TabView"
                    && frameworkId == "XAML")
                    return true
            }

            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } finally {
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_TabSwitch_IsExplorerTabAtPoint(screenX, screenY) {
    global ME_State
    currentPtr := 0
    nextPtr := 0
    stage := 0
    depth := 0
    maxDepth := ME_State.TabSwitch.ExplorerAncestryMaxDepth

    try {
        ; element/parentは呼出元owned。AOT用local UIAには接続しない。
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY)
        if (!currentPtr)
            return false

        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType))
                return false

            if (stage = 0 && controlType = 50019) {
                if (!ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (className == "ListViewItem" && frameworkId == "XAML")
                    stage := 1
            } else if (stage = 1 && controlType = 50008) {
                if (!ME_UIA_GetProperty(currentPtr, 30011, automationId)
                    || !ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (automationId == "TabListView" && className == "ListView"
                    && frameworkId == "XAML")
                    stage := 2
            } else if (stage = 2 && controlType = 50018) {
                if (!ME_UIA_GetProperty(currentPtr, 30011, automationId)
                    || !ME_UIA_GetProperty(currentPtr, 30012, className)
                    || !ME_UIA_GetProperty(currentPtr, 30024, frameworkId))
                    return false
                if (automationId == "TabView"
                    && className == "Microsoft.UI.Xaml.Controls.TabView"
                    && frameworkId == "XAML")
                    return true
            }

            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } finally {
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_TabSwitch_FindSysTabControlAncestor(pointHwnd) {
    if (!pointHwnd || !DllCall("User32\IsWindow", "Ptr", pointHwnd, "Int"))
        return 0
    rootHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (!rootHwnd)
        return 0

    currentHwnd := pointHwnd
    maxDepth := 16
    depth := 0
    while (currentHwnd && depth < maxDepth) {
        depth += 1
        if (!DllCall("User32\IsWindow", "Ptr", currentHwnd, "Int"))
            return 0
        if (ME_TabSwitch_GetWindowClassName(currentHwnd, className)
            && className == "SysTabControl32")
            return currentHwnd
        if (currentHwnd = rootHwnd)
            break
        parentHwnd := DllCall("User32\GetParent", "Ptr", currentHwnd, "Ptr")
        if (!parentHwnd
            || DllCall("User32\GetAncestor", "Ptr", parentHwnd, "UInt", 2, "Ptr") != rootHwnd)
            break
        currentHwnd := parentHwnd
    }
    return 0
}

ME_TabSwitch_GetWindowClassName(hwnd, ByRef className) {
    className := ""
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    VarSetCapacity(classBuffer, 512, 0)
    classLength := DllCall("User32\GetClassNameW", "Ptr", hwnd
        , "Ptr", &classBuffer, "Int", 256, "Int")
    if (classLength <= 0)
        return false
    className := StrGet(&classBuffer, classLength, "UTF-16")
    return true
}

ME_TabSwitch_IsSysTabControlWindow(controlHwnd) {
    if (!controlHwnd || !DllCall("User32\IsWindow", "Ptr", controlHwnd, "Int")
        || !DllCall("User32\IsWindowVisible", "Ptr", controlHwnd, "Int")
        || !DllCall("User32\IsWindowEnabled", "Ptr", controlHwnd, "Int"))
        return false
    return (ME_TabSwitch_GetWindowClassName(controlHwnd, className)
        && className == "SysTabControl32") ? true : false
}

ME_TabSwitch_IsPointInsideWindow(hwnd, screenX, screenY) {
    if (!ME_GetWindowRectangle(hwnd, rectangle))
        return false
    return (screenX >= rectangle.Left && screenX < rectangle.Right
        && screenY >= rectangle.Top && screenY < rectangle.Bottom) ? true : false
}

ME_TabSwitch_IsSysTabAtPointUIA(controlHwnd, screenX, screenY) {
    global ME_State
    ; controlHwndのnative class/cursor/root検証は呼出元で完了済み。
    currentPtr := 0
    nextPtr := 0
    tabItemFound := false
    depth := 0
    maxDepth := ME_State.TabSwitch.SysTabAncestryMaxDepth

    try {
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY)
        if (!currentPtr)
            return false

        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType))
                return false
            if (!tabItemFound) {
                if (controlType = 50019)
                    tabItemFound := true
            } else if (controlType = 50018)
                return true

            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } finally {
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_TabSwitch_IsSysTabAtPointMSAA(controlHwnd, screenX, screenY) {
    accessiblePtr := 0
    accessibleHwnd := 0
    VarSetCapacity(iidAccessible, 16, 0)
    VarSetCapacity(hitVariant, 8 + 2 * A_PtrSize, 0)
    try {
        if (!ME_TabSwitch_IsSysTabControlWindow(controlHwnd)
            || !ME_TabSwitch_IsPointInsideWindow(controlHwnd, screenX, screenY))
            return false
        pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
        if (!pointHwnd
            || ME_TabSwitch_FindSysTabControlAncestor(pointHwnd) != controlHwnd)
            return false
        rootHwnd := DllCall("User32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr")
        if (!rootHwnd || DllCall("User32\GetForegroundWindow", "Ptr") != rootHwnd)
            return false

        hresult := DllCall("Ole32\CLSIDFromString"
            , "WStr", "{618736E0-3C3D-11CF-810C-00AA00389B71}"
            , "Ptr", &iidAccessible, "Int")
        if (hresult < 0)
            return false

        hresult := DllCall("Oleacc\AccessibleObjectFromWindow", "Ptr", controlHwnd
            , "UInt", 0xFFFFFFFC, "Ptr", &iidAccessible
            , "PtrP", accessiblePtr, "Int") ; OBJID_CLIENT = -4
        if (hresult < 0 || !accessiblePtr)
            return false

        hresult := DllCall("Oleacc\WindowFromAccessibleObject", "Ptr", accessiblePtr
            , "PtrP", accessibleHwnd, "Int")
        if (hresult < 0 || !accessibleHwnd || accessibleHwnd != controlHwnd)
            return false

        method := ME_ComMethod(accessiblePtr, 24) ; IAccessible::accHitTest
        if (!method)
            return false
        hresult := DllCall(method, "Ptr", accessiblePtr
            , "Int", screenX, "Int", screenY, "Ptr", &hitVariant, "Int")
        if (hresult < 0)
            return false
        variantType := NumGet(hitVariant, 0, "UShort")
        if (variantType != 3) ; VT_I4
            return false
        childId := NumGet(hitVariant, 8, "Int")
        if (childId <= 0) ; CHILDID_SELF(0)と負値は曖昧なので拒否する。
            return false
        return true
    } finally {
        try {
            DllCall("OleAut32\VariantClear", "Ptr", &hitVariant)
        } finally {
            if (accessiblePtr) {
                releasedPtr := accessiblePtr
                accessiblePtr := 0
                ME_ComRelease(releasedPtr)
            }
        }
    }
}

ME_TabSwitch_MatchesTabItem(adapter, controlType, className, frameworkId) {
    if (controlType != 50019)
        return false
    if (adapter == "Firefox")
        return (className == "tabbrowser-tab" && frameworkId == "Gecko")
    if (adapter == "Chrome")
        return (className == "Tab" && frameworkId == "Chrome")
    if (adapter == "Edge")
        return (className == "EdgeTab" && frameworkId == "Chrome")
    return false
}

ME_TabSwitch_MatchesTabContainer(adapter, controlType, className, frameworkId) {
    if (controlType != 50018)
        return false
    if (adapter == "Chrome")
        return (className == "TabContainerImpl" && frameworkId == "Chrome")
    if (adapter == "Edge")
        return (className == "EdgeTabContainerImpl" && frameworkId == "Chrome")
    return false
}

ME_TabSwitch_HandleWheel(input) {
    global ME_Config, ME_State
    state := ME_State.TabSwitch
    if (!IsObject(input) || !state.Initialized || state.CleanupStarted
        || !ME_Config.EnableFunction.TabSwitch || !ME_CanRouteMouseInput()
        || ME_State.SyntheticInputDepth > 0)
        return false

    direction := input.Direction
    if (!(direction == "Up" || direction == "Down"))
        return false
    stepText := Trim(input.Steps)
    if (!ME_IsIntegerString(stepText) || stepText + 0 < 1)
        return false
    stepCount := stepText + 0

    if (!IsObject(state.Candidate) && !ME_TabSwitch_PrepareTarget())
        return false
    candidate := state.Candidate
    if (!ME_TabSwitch_IsCandidateValid(candidate)) {
        state.Candidate := false
        return false
    }

    state.Candidate := false
    shortcutCallback := Func("ME_TabSwitch_SendShortcut")
    return ME_RunWithSyntheticInput(shortcutCallback, direction, stepCount)
}

ME_TabSwitch_IsCandidateValid(candidate) {
    global ME_Config, ME_State
    if (!IsObject(candidate) || !candidate.TargetHwnd
        || !ME_TabSwitch_IsAdapterEnabled(candidate.Adapter))
        return false
    elapsed := A_TickCount - candidate.Tick
    if (elapsed < 0)
        elapsed += 0x100000000
    if (elapsed > ME_State.TabSwitch.CandidateLifetimeMs)
        return false

    targetHwnd := candidate.TargetHwnd
    if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(targetHwnd)
        || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != candidate.ProcessId || threadId != candidate.ThreadId
        || !(className == candidate.ClassName))
        return false
    if (DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd)
        return false
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
        return false
    currentRootHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
    if (currentRootHwnd != targetHwnd)
        return false
    if (candidate.Adapter == "SysTabControl32") {
        if (!candidate.HasKey("ControlHwnd") || !candidate.ControlHwnd)
            return false
        currentControlHwnd := ME_TabSwitch_FindSysTabControlAncestor(pointHwnd)
        if (currentControlHwnd != candidate.ControlHwnd
            || !ME_TabSwitch_IsSysTabControlWindow(currentControlHwnd)
            || DllCall("User32\GetAncestor", "Ptr", currentControlHwnd
                , "UInt", 2, "Ptr") != targetHwnd)
            return false
    }
    if (candidate.Adapter == "TabSpecial") {
        if (!ME_TabSwitch_IsSpecialCandidateValid(candidate))
            return false
    }
    if (ME_Config.TabIgnore.MaxIndex()) {
        if (ME_TabSwitch_ShouldIgnoreCurrentTarget(candidate))
            return false
    }
    return true
}

ME_TabSwitch_SendShortcut(direction, stepCount) {
    if (!(direction == "Up" || direction == "Down")
        || !ME_IsIntegerString(stepCount) || stepCount + 0 < 1)
        return false
    Loop, % stepCount {
        if (direction == "Up")
            SendInput, ^+{Tab}
        else
            SendInput, ^{Tab}
    }
    return true
}

ME_TabSwitch_Cleanup() {
    global ME_State
    state := ME_State.TabSwitch
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    state.Candidate := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; ExplorerViewMode (Phase 2-5)
; -----------------------------------------------------------------------------


ME_InitializeExplorerViewMode() {
    global ME_Config, ME_State
    state := ME_State.ExplorerViewMode
    if (state.Initialized)
        return true
    state.Initialized := true
    if (!ME_Config.EnableFunction.ExplorerViewMode || ME_MouseGestureL_IsEditMode())
        return true
    if (!ME_InitializeWheelInput()) {
        state.Initialized := false
        return false
    }
    return true
}

ME_ExplorerViewMode_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.ExplorerViewMode
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.EnableFunction.ExplorerViewMode && ME_CanRouteMouseInput()
        && ME_State.SyntheticInputDepth = 0 && !ME_MouseGestureL_IsEditMode()) ? true : false
}

ME_ExplorerViewMode_BeginProbe(ByRef previousCritical) {
    global ME_State
    previousCritical := A_IsCritical
    Critical, On
    state := ME_State.ExplorerViewMode
    if (state.ProbeBusy || state.CleanupStarted || ME_State.CleanupStarted) {
        Critical, % previousCritical
        return false
    }
    state.ProbeBusy := true
    Critical, Off
    return true
}

ME_ExplorerViewMode_EndProbe(previousCritical) {
    global ME_State
    Critical, On
    ME_State.ExplorerViewMode.ProbeBusy := false
    Critical, % previousCritical
}

ME_ExplorerViewMode_IsTargetCurrent(candidate) {
    if (!IsObject(candidate) || !candidate.TargetHwnd || !ME_ExplorerViewMode_CanOperate())
        return false
    targetHwnd := candidate.TargetHwnd
    if (!ME_AlwaysOnTop_IsExplorerWindow(targetHwnd)
        || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className)
        || processId != candidate.ProcessId || threadId != candidate.ThreadId
        || !(className == candidate.ClassName) || !(className == "CabinetWClass"))
        return false
    return (DllCall("User32\GetForegroundWindow", "Ptr") = targetHwnd) ? true : false
}

ME_ExplorerViewMode_IsTopChild(pointHwnd, targetHwnd) {
    if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd)
        || DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr") != targetHwnd
        || !ME_AlwaysOnTop_GetWindowIdentity(pointHwnd, processId, threadId, className))
        return false
    prefix := "Microsoft.UI.Content.DesktopChildSiteBridge"
    return (SubStr(className, 1, StrLen(prefix)) == prefix
        || className == "TITLE_BAR_SCAFFOLDING_WINDOW_CLASS") ? true : false
}

ME_ExplorerViewMode_GetTopPoint(targetHwnd, ByRef screenX, ByRef screenY, ByRef pointHwnd) {
    pointHwnd := 0
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    return ME_ExplorerViewMode_IsTopChild(pointHwnd, targetHwnd)
}

ME_ExplorerViewMode_PrepareTarget() {
    global ME_State
    state := ME_State.ExplorerViewMode
    state.Candidate := false
    if (!ME_ExplorerViewMode_CanOperate() || !ME_ExplorerViewMode_BeginProbe(previousCritical))
        return false
    try {
        if (!ME_GetCursorScreenPoint(screenX, screenY))
            return false
        pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
        if (!pointHwnd || ME_AlwaysOnTop_IsFrameWindow(pointHwnd))
            return false
        targetHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr")
        if (!ME_ExplorerViewMode_IsTopChild(pointHwnd, targetHwnd)
            || !ME_AlwaysOnTop_IsExplorerWindow(targetHwnd)
            || DllCall("User32\GetForegroundWindow", "Ptr") != targetHwnd
            || !ME_AlwaysOnTop_GetWindowIdentity(targetHwnd, processId, threadId, className))
            return false
        if (!ME_ExplorerViewMode_IsTopArea(targetHwnd, screenX, screenY))
            return false
        ; capture criterionではShell COMを呼ばず、上部領域のscalar情報だけを保存する。
        candidate := {TargetHwnd: targetHwnd, ProcessId: processId
            , ThreadId: threadId, ClassName: className
            , ScreenX: screenX, ScreenY: screenY, Tick: 0}
        ; local UIA問い合わせ後は同一point/root/childを必須とする。
        ; action前のCandidate validationではfresh UIAをもう一度行う。
        if (!ME_ExplorerViewMode_IsTargetCurrent(candidate)
            || !ME_ExplorerViewMode_GetTopPoint(targetHwnd, currentX, currentY, currentPoint)
            || currentX != screenX || currentY != screenY || currentPoint != pointHwnd)
            return false
        candidate.Tick := A_TickCount
        state.Candidate := candidate
        return true
    } catch error {
        return false
    } finally {
        ME_ExplorerViewMode_EndProbe(previousCritical)
    }
}

ME_ExplorerViewMode_IsCandidateValid(candidate) {
    global ME_State
    if (!IsObject(candidate) || !candidate.TargetHwnd
        || !candidate.HasKey("Tick") || !ME_ExplorerViewMode_CanOperate())
        return false
    elapsed := A_TickCount - candidate.Tick
    if (elapsed < 0)
        elapsed += 0x100000000
    if (elapsed > ME_State.ExplorerViewMode.CandidateLifetimeMs)
        return false
    if (!ME_ExplorerViewMode_BeginProbe(previousCritical))
        return false
    try {
        if (!ME_ExplorerViewMode_IsTargetCurrent(candidate)
            || !ME_ExplorerViewMode_GetTopPoint(candidate.TargetHwnd, screenX, screenY, pointHwnd)
            || !ME_ExplorerViewMode_IsTopArea(candidate.TargetHwnd, screenX, screenY))
            return false
        return (ME_ExplorerViewMode_IsTargetCurrent(candidate)
            && ME_ExplorerViewMode_GetTopPoint(candidate.TargetHwnd, currentX, currentY, currentPoint)
            && currentX = screenX && currentY = screenY && currentPoint = pointHwnd
            && ME_ExplorerViewMode_IsTopArea(candidate.TargetHwnd, currentX, currentY)) ? true : false
    } catch error {
        return false
    } finally {
        ME_ExplorerViewMode_EndProbe(previousCritical)
    }
}

ME_ExplorerViewMode_HandleWheel(input) {
    global ME_State
    state := ME_State.ExplorerViewMode
    if (!IsObject(input) || !ME_ExplorerViewMode_CanOperate())
        return false
    direction := input.Direction
    if (!(direction == "Up" || direction == "Down"))
        return false
    stepText := Trim(input.Steps)
    if (!ME_IsIntegerString(stepText) || stepText + 0 < 1)
        return false
    if (!IsObject(state.Candidate) && !ME_ExplorerViewMode_PrepareTarget())
        return false
    candidate := state.Candidate
    state.Candidate := false
    if (!ME_ExplorerViewMode_IsCandidateValid(candidate))
        return false
    return ME_ExplorerViewMode_Apply(candidate, direction, stepText + 0)
}

ME_ExplorerViewMode_IsTopArea(targetHwnd, screenX, screenY) {
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!ME_ExplorerViewMode_IsTopChild(pointHwnd, targetHwnd))
        return false
    ; この機能専用の短寿命session。共有UIAサービス/共有walkerを使わない。
    automationPtr := 0
    walkerPtr := 0
    elementPtr := 0
    currentPtr := 0
    parentPtr := 0
    try {
        automationPtr := ComObjCreate("{FF48DBA4-60EF-4201-AA87-54103EEF594E}"
            , "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        if (!automationPtr)
            return false
        method := ME_ComMethod(automationPtr, 7) ; IUIAutomation::ElementFromPoint
        if (!method)
            return false
        hresult := DllCall(method, "Ptr", automationPtr, "Int64", ME_PackPoint64(screenX, screenY)
            , "PtrP", elementPtr, "Int")
        if (hresult < 0 || !elementPtr
            || !ME_UIA_GetProperty(elementPtr, 30003, controlType)
            || !ME_UIA_GetProperty(elementPtr, 30005, elementName)
            || controlType != 50037 || !(elementName == "" || elementName == "TitleBar"))
            return false
        method := ME_ComMethod(automationPtr, 16) ; get_RawViewWalker
        if (!method)
            return false
        hresult := DllCall(method, "Ptr", automationPtr, "PtrP", walkerPtr, "Int")
        if (hresult < 0 || !walkerPtr)
            return false
        currentPtr := ME_ExplorerViewMode_GetParentLocal(walkerPtr, elementPtr)
        ownedPtr := elementPtr
        elementPtr := 0
        ME_ComRelease(ownedPtr)
        depth := 0
        while (currentPtr && depth < 10) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, ancestorType)
                || !ME_UIA_GetProperty(currentPtr, 30012, ancestorClass)
                || !ME_UIA_GetProperty(currentPtr, 30024, ancestorFramework))
                return false
            if (ancestorType = 50032 && ancestorClass == "CabinetWClass"
                && ancestorFramework == "Win32")
                return true
            if (depth >= 10)
                break
            parentPtr := ME_ExplorerViewMode_GetParentLocal(walkerPtr, currentPtr)
            ownedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(ownedPtr)
            currentPtr := parentPtr
            parentPtr := 0
        }
        return false
    } finally {
        if (parentPtr) {
            ownedPtr := parentPtr
            parentPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (currentPtr) {
            ownedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (elementPtr) {
            ownedPtr := elementPtr
            elementPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (walkerPtr) {
            ownedPtr := walkerPtr
            walkerPtr := 0
            ME_ComRelease(ownedPtr)
        }
        if (automationPtr) {
            ownedPtr := automationPtr
            automationPtr := 0
            ME_ComRelease(ownedPtr)
        }
    }
}

ME_ExplorerViewMode_GetParentLocal(walkerPtr, elementPtr) {
    parentPtr := 0
    try {
        if (!walkerPtr || !elementPtr)
            return 0
        method := ME_ComMethod(walkerPtr, 3) ; IUIAutomationTreeWalker::GetParentElement
        if (!method)
            return 0
        hresult := DllCall(method, "Ptr", walkerPtr, "Ptr", elementPtr, "PtrP", parentPtr, "Int")
        if (hresult < 0 || !parentPtr)
            return 0
        resultPtr := parentPtr
        parentPtr := 0
        return resultPtr ; 所有参照を呼出元へ移譲。
    } finally {
        if (parentPtr) {
            ownedPtr := parentPtr
            parentPtr := 0
            ME_ComRelease(ownedPtr)
        }
    }
}

ME_ExplorerViewMode_MakeGuid(ByRef guid, text) {
    VarSetCapacity(guid, 16, 0)
    hresult := DllCall("Ole32\CLSIDFromString", "WStr", text, "Ptr", &guid, "Int")
    return (hresult >= 0) ? true : false
}

ME_ExplorerViewMode_QueryInterface(interfacePtr, ByRef iid, ByRef resultPtr) {
    resultPtr := 0
    method := ME_ComMethod(interfacePtr, 0) ; IUnknown::QueryInterface
    if (!method)
        return false
    hresult := DllCall(method, "Ptr", interfacePtr, "Ptr", &iid, "PtrP", resultPtr, "Int")
    return (hresult >= 0 && resultPtr) ? true : false
}

ME_ExplorerViewMode_ReleaseOwned(ByRef interfacePtr) {
    if (!interfacePtr)
        return
    ownedPtr := interfacePtr
    interfacePtr := 0
    ME_ComRelease(ownedPtr)
}

ME_ExplorerViewMode_IsStrictViewWindow(viewHwnd, targetHwnd) {
    return (viewHwnd && DllCall("User32\IsWindow", "Ptr", viewHwnd, "Int")
        && DllCall("User32\IsChild", "Ptr", targetHwnd, "Ptr", viewHwnd, "Int")
        && DllCall("User32\GetAncestor", "Ptr", viewHwnd, "UInt", 2, "Ptr") = targetHwnd) ? true : false
}

ME_ExplorerViewMode_ResolveActiveFolderView(targetHwnd, ByRef resolved) {
    resolved := false
    shellApplication := false
    shellWindows := false
    dispatch := false
    matches := []
    uniqueViews := []
    pWebBrowserApp := 0
    pServiceProvider := 0
    pShellBrowser := 0
    pShellView := 0
    pIdentity := 0
    pFolderView2 := 0
    try {
        if (!targetHwnd || !ME_AlwaysOnTop_IsExplorerWindow(targetHwnd))
            return false
        if (!ME_ExplorerViewMode_MakeGuid(iidWebBrowserApp
            , "{0002DF05-0000-0000-C000-000000000046}")
            || !ME_ExplorerViewMode_MakeGuid(iidServiceProvider
                , "{6D5140C1-7436-11CE-8034-00AA006009FA}")
            || !ME_ExplorerViewMode_MakeGuid(sidTopLevelBrowser
                , "{4C96BE40-915C-11CF-99D3-00AA004AE837}")
            || !ME_ExplorerViewMode_MakeGuid(iidShellBrowser
                , "{000214E2-0000-0000-C000-000000000046}")
            || !ME_ExplorerViewMode_MakeGuid(iidUnknown
                , "{00000000-0000-0000-C000-000000000046}")
            || !ME_ExplorerViewMode_MakeGuid(iidFolderView2
                , "{1AF3A467-214F-4298-908E-06B03E0B39F9}"))
            return false

        shellApplication := ComObjCreate("Shell.Application")
        shellWindows := shellApplication.Windows
        if (!IsObject(shellWindows))
            return false
        windowCount := shellWindows.Count + 0
        if (!ME_IsIntegerString(windowCount) || windowCount < 0)
            return false

        Loop, % windowCount {
            dispatch := shellWindows.Item(A_Index - 1)
            if (!IsObject(dispatch))
                return false
            borrowedPtr := ComObjValue(dispatch)
            if (!borrowedPtr
                || !ME_ExplorerViewMode_QueryInterface(borrowedPtr
                    , iidWebBrowserApp, pWebBrowserApp))
                return false
            dispatchHwnd := 0
            method := ME_ComMethod(pWebBrowserApp, 37) ; IWebBrowserApp::get_HWND
            if (!method) {
                ME_ExplorerViewMode_ReleaseOwned(pWebBrowserApp)
                return false
            }
            hresult := DllCall(method, "Ptr", pWebBrowserApp
                , "Int64P", dispatchHwnd, "Int")
            ME_ExplorerViewMode_ReleaseOwned(pWebBrowserApp)
            if (hresult < 0 || !dispatchHwnd)
                return false
            if (dispatchHwnd = targetHwnd)
                matches.Push(dispatch)
            dispatch := false
        }
        if (shellWindows.Count + 0 != windowCount || !matches.MaxIndex())
            return false

        for index, dispatch in matches {
            borrowedPtr := ComObjValue(dispatch)
            if (!borrowedPtr
                || !ME_ExplorerViewMode_QueryInterface(borrowedPtr
                    , iidServiceProvider, pServiceProvider))
                return false
            method := ME_ComMethod(pServiceProvider, 3) ; IServiceProvider::QueryService
            if (!method)
                return false
            hresult := DllCall(method, "Ptr", pServiceProvider
                , "Ptr", &sidTopLevelBrowser, "Ptr", &iidShellBrowser
                , "PtrP", pShellBrowser, "Int")
            if (hresult < 0 || !pShellBrowser)
                return false
            method := ME_ComMethod(pShellBrowser, 15) ; IShellBrowser::QueryActiveShellView
            if (!method)
                return false
            hresult := DllCall(method, "Ptr", pShellBrowser, "PtrP", pShellView, "Int")
            if (hresult < 0 || !pShellView
                || !ME_ExplorerViewMode_QueryInterface(pShellView, iidUnknown, pIdentity))
                return false
            method := ME_ComMethod(pShellView, 3) ; IOleWindow::GetWindow
            if (!method)
                return false
            viewHwnd := 0
            hresult := DllCall(method, "Ptr", pShellView, "PtrP", viewHwnd, "Int")
            if (hresult < 0
                || !ME_ExplorerViewMode_IsStrictViewWindow(viewHwnd, targetHwnd))
                return false

            duplicateIndex := 0
            for uniqueIndex, item in uniqueViews {
                if (pIdentity = item.IdentityPtr) {
                    duplicateIndex := uniqueIndex
                    break
                }
            }
            if (duplicateIndex) {
                if (viewHwnd != uniqueViews[duplicateIndex].ViewHwnd)
                    return false
                ME_ExplorerViewMode_ReleaseOwned(pIdentity)
                ME_ExplorerViewMode_ReleaseOwned(pShellView)
            } else {
                uniqueViews.Push({ShellViewPtr: pShellView
                    , IdentityPtr: pIdentity, ViewHwnd: viewHwnd})
                pShellView := 0
                pIdentity := 0
            }
            ME_ExplorerViewMode_ReleaseOwned(pShellBrowser)
            ME_ExplorerViewMode_ReleaseOwned(pServiceProvider)
            dispatch := false
        }
        if (!uniqueViews.MaxIndex())
            return false

        for index, item in uniqueViews {
            VarSetCapacity(rect, 16, 0)
            if (!DllCall("User32\GetWindowRect", "Ptr", item.ViewHwnd
                , "Ptr", &rect, "Int"))
                return false
            rectLeft := NumGet(rect, 0, "Int")
            rectTop := NumGet(rect, 4, "Int")
            rectRight := NumGet(rect, 8, "Int")
            rectBottom := NumGet(rect, 12, "Int")
            if (rectLeft >= rectRight || rectTop >= rectBottom)
                return false
            if (index = 1) {
                commonLeft := rectLeft
                commonTop := rectTop
                commonRight := rectRight
                commonBottom := rectBottom
            } else {
                if (rectLeft > commonLeft)
                    commonLeft := rectLeft
                if (rectTop > commonTop)
                    commonTop := rectTop
                if (rectRight < commonRight)
                    commonRight := rectRight
                if (rectBottom < commonBottom)
                    commonBottom := rectBottom
            }
        }
        if (commonRight <= commonLeft || commonBottom <= commonTop)
            return false

        pointX := commonLeft + Floor((commonRight - commonLeft) / 2)
        pointY := commonTop + Floor((commonBottom - commonTop) / 2)
        hitHwnd := DllCall("User32\WindowFromPoint", "Int64"
            , ME_PackPoint64(pointX, pointY), "Ptr")
        if (!hitHwnd || !DllCall("User32\IsWindow", "Ptr", hitHwnd, "Int"))
            return false
        selectedIndex := 0
        for index, item in uniqueViews {
            if (hitHwnd = item.ViewHwnd
                || DllCall("User32\IsChild", "Ptr", item.ViewHwnd, "Ptr", hitHwnd, "Int")) {
                if (selectedIndex)
                    return false
                selectedIndex := index
            }
        }
        if (!selectedIndex)
            return false

        selected := uniqueViews[selectedIndex]
        if (!ME_ExplorerViewMode_QueryInterface(selected.ShellViewPtr
            , iidFolderView2, pFolderView2))
            return false
        resolved := {ShellViewPtr: selected.ShellViewPtr
            , IdentityPtr: selected.IdentityPtr
            , FolderViewPtr: pFolderView2, ViewHwnd: selected.ViewHwnd}
        selected.ShellViewPtr := 0
        selected.IdentityPtr := 0
        pFolderView2 := 0
        return true
    } catch error {
        resolved := false
        return false
    } finally {
        ME_ExplorerViewMode_ReleaseOwned(pFolderView2)
        ME_ExplorerViewMode_ReleaseOwned(pIdentity)
        ME_ExplorerViewMode_ReleaseOwned(pShellView)
        ME_ExplorerViewMode_ReleaseOwned(pShellBrowser)
        ME_ExplorerViewMode_ReleaseOwned(pServiceProvider)
        ME_ExplorerViewMode_ReleaseOwned(pWebBrowserApp)
        if (IsObject(uniqueViews)) {
            Loop, % uniqueViews.MaxIndex() {
                releaseIndex := uniqueViews.MaxIndex() - A_Index + 1
                item := uniqueViews[releaseIndex]
                ownedPtr := item.IdentityPtr
                item.IdentityPtr := 0
                if (ownedPtr)
                    ME_ComRelease(ownedPtr)
                ownedPtr := item.ShellViewPtr
                item.ShellViewPtr := 0
                if (ownedPtr)
                    ME_ComRelease(ownedPtr)
            }
        }
        dispatch := false
        matches := false
        uniqueViews := false
        shellWindows := false
        shellApplication := false
    }
}

ME_ExplorerViewMode_ReleaseResolved(ByRef resolved) {
    if (!IsObject(resolved)) {
        resolved := false
        return
    }
    ownedPtr := resolved.FolderViewPtr
    resolved.FolderViewPtr := 0
    if (ownedPtr)
        ME_ComRelease(ownedPtr)
    ownedPtr := resolved.IdentityPtr
    resolved.IdentityPtr := 0
    if (ownedPtr)
        ME_ComRelease(ownedPtr)
    ownedPtr := resolved.ShellViewPtr
    resolved.ShellViewPtr := 0
    if (ownedPtr)
        ME_ComRelease(ownedPtr)
    resolved := false
}

ME_ExplorerViewMode_ReadPresetPair(resolved, ByRef viewMode, ByRef iconSize) {
    viewMode := 0
    iconSize := 0
    if (!IsObject(resolved) || !resolved.FolderViewPtr)
        return false
    method := ME_ComMethod(resolved.FolderViewPtr, 36) ; IFolderView2::GetViewModeAndIconSize
    if (!method)
        return false
    hresult := DllCall(method, "Ptr", resolved.FolderViewPtr
        , "IntP", viewMode, "IntP", iconSize, "Int")
    return (hresult >= 0) ? true : false
}

ME_ExplorerViewMode_GetPresetIndex(viewMode, iconSize) {
    if (viewMode = 1 && iconSize = 256)
        return 1
    if (viewMode = 1 && iconSize = 96)
        return 2
    if (viewMode = 1 && iconSize = 48)
        return 3
    if (viewMode = 2 && iconSize = 16)
        return 4
    if (viewMode = 3 && iconSize = 16)
        return 5
    if (viewMode = 4 && iconSize = 16)
        return 6
    if (viewMode = 6 && iconSize = 48)
        return 7
    if (viewMode = 8 && iconSize = 32)
        return 8
    return 0
}

ME_ExplorerViewMode_GetPreset(index, ByRef viewMode, ByRef iconSize) {
    viewMode := 0
    iconSize := 0
    if (index = 1) {
        viewMode := 1
        iconSize := 256
    } else if (index = 2) {
        viewMode := 1
        iconSize := 96
    } else if (index = 3) {
        viewMode := 1
        iconSize := 48
    } else if (index = 4) {
        viewMode := 2
        iconSize := 16
    } else if (index = 5) {
        viewMode := 3
        iconSize := 16
    } else if (index = 6) {
        viewMode := 4
        iconSize := 16
    } else if (index = 7) {
        viewMode := 6
        iconSize := 48
    } else if (index = 8) {
        viewMode := 8
        iconSize := 32
    } else {
        return false
    }
    return true
}

ME_ExplorerViewMode_IsDpi96(targetHwnd) {
    dpi := DllCall("User32\GetDpiForWindow", "Ptr", targetHwnd, "UInt")
    return (dpi = 96) ? true : false
}

ME_ExplorerViewMode_Apply(candidate, direction, stepCount) {
    if (!IsObject(candidate) || !candidate.TargetHwnd
        || !(direction == "Up" || direction == "Down")
        || !ME_IsIntegerString(stepCount) || stepCount + 0 < 1
        || !ME_ExplorerViewMode_CanOperate())
        return false
    if (!ME_ExplorerViewMode_BeginProbe(previousCritical))
        return false
    initial := false
    fresh := false
    try {
        targetHwnd := candidate.TargetHwnd
        if (!ME_ExplorerViewMode_IsTargetCurrent(candidate)
            || !ME_ExplorerViewMode_GetTopPoint(targetHwnd, screenX, screenY, pointHwnd)
            || !ME_ExplorerViewMode_IsTopArea(targetHwnd, screenX, screenY)
            || !ME_ExplorerViewMode_IsDpi96(targetHwnd)
            || !ME_ExplorerViewMode_ResolveActiveFolderView(targetHwnd, initial)
            || !ME_ExplorerViewMode_ReadPresetPair(initial, initialMode, initialIconSize))
            return false
        currentIndex := ME_ExplorerViewMode_GetPresetIndex(initialMode, initialIconSize)
        if (!currentIndex)
            return false

        stepCount += 0
        offset := Mod(stepCount, 8)
        if (direction == "Up")
            nextIndex := Mod(currentIndex - 1 - offset + 8, 8) + 1
        else
            nextIndex := Mod(currentIndex - 1 + offset, 8) + 1
        if (!ME_ExplorerViewMode_GetPreset(nextIndex, targetMode, targetIconSize))
            return false

        if (!ME_ExplorerViewMode_IsTargetCurrent(candidate)
            || !ME_ExplorerViewMode_GetTopPoint(targetHwnd, currentX, currentY, currentPoint)
            || currentX != screenX || currentY != screenY || currentPoint != pointHwnd
            || !ME_ExplorerViewMode_IsTopArea(targetHwnd, currentX, currentY)
            || !ME_ExplorerViewMode_ResolveActiveFolderView(targetHwnd, fresh)
            || !IsObject(fresh) || fresh.IdentityPtr != initial.IdentityPtr
            || fresh.ViewHwnd != initial.ViewHwnd
            || !ME_ExplorerViewMode_IsDpi96(targetHwnd)
            || !ME_ExplorerViewMode_ReadPresetPair(fresh, freshMode, freshIconSize)
            || freshMode != initialMode || freshIconSize != initialIconSize
            || ME_ExplorerViewMode_GetPresetIndex(freshMode, freshIconSize) != currentIndex
            || !ME_ExplorerViewMode_IsTargetCurrent(candidate)
            || !ME_ExplorerViewMode_GetTopPoint(targetHwnd, finalX, finalY, finalPoint)
            || finalX != screenX || finalY != screenY || finalPoint != pointHwnd
            || !ME_ExplorerViewMode_IsTopArea(targetHwnd, finalX, finalY)
            || !ME_ExplorerViewMode_IsDpi96(targetHwnd))
            return false

        if (nextIndex = currentIndex)
            return true

        method := ME_ComMethod(fresh.FolderViewPtr, 35) ; IFolderView2::SetViewModeAndIconSize
        if (!method)
            return false
        hresult := DllCall(method, "Ptr", fresh.FolderViewPtr
            , "Int", targetMode, "Int", targetIconSize, "Int")
        return (hresult >= 0) ? true : false
    } catch error {
        return false
    } finally {
        ME_ExplorerViewMode_ReleaseResolved(fresh)
        ME_ExplorerViewMode_ReleaseResolved(initial)
        ME_ExplorerViewMode_EndProbe(previousCritical)
    }
}

ME_ExplorerViewMode_Cleanup() {
    global ME_State
    state := ME_State.ExplorerViewMode
    state.CleanupStarted := true
    state.Candidate := false
    state.ProbeBusy := false
    state.Initialized := false
}

; -----------------------------------------------------------------------------
; SpecialScrollbarScroll (v1.0.0: classic Win32 + strict XAML UIA)
; -----------------------------------------------------------------------------

ME_InitializeSpecialScrollbarScroll() {
    global ME_Config, ME_State
    state := ME_State.SpecialScrollbarScroll
    if (state.Initialized)
        return true
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false
    state.Initialized := true
    if (!ME_Config.EnableFunction.SpecialScrollbarScroll
        || ME_MouseGestureL_IsEditMode()
        || (ME_Config.SpecialScrollbarScroll.Vertical = 0
            && ME_Config.SpecialScrollbarScroll.Horizontal = 0))
        return true
    if (!ME_InitializeWheelInput()) {
        state.Initialized := false
        return false
    }
    return true
}

ME_SpecialScrollbarScroll_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.SpecialScrollbarScroll
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.EnableFunction.SpecialScrollbarScroll
        && (ME_Config.SpecialScrollbarScroll.Vertical != 0
            || ME_Config.SpecialScrollbarScroll.Horizontal != 0)
        && ME_CanRouteMouseInput() && ME_State.SyntheticInputDepth = 0
        && !ME_MouseGestureL_IsEditMode()) ? true : false
}

ME_SpecialScrollbarScroll_GetAxisValue(axis, ByRef value) {
    global ME_Config
    value := 0
    if (axis == "Vertical")
        value := ME_Config.SpecialScrollbarScroll.Vertical
    else if (axis == "Horizontal")
        value := ME_Config.SpecialScrollbarScroll.Horizontal
    else
        return false
    if (IsObject(value) || !ME_IsIntegerString(value)
        || !(value = -2 || value = -1 || (value >= 0 && value <= 10)))
        return false
    return true
}

ME_SpecialScrollbarScroll_GetWindowIdentity(hwnd, ByRef processId
    , ByRef threadId, ByRef className) {
    processId := 0
    threadId := 0
    className := ""
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    threadId := DllCall("User32\GetWindowThreadProcessId", "Ptr", hwnd
        , "UIntP", processId, "UInt")
    if (!threadId || !processId)
        return false
    VarSetCapacity(classBuffer, 512, 0)
    classLength := DllCall("User32\GetClassNameW", "Ptr", hwnd
        , "Ptr", &classBuffer, "Int", 256, "Int")
    if (classLength <= 0)
        return false
    className := StrGet(&classBuffer, classLength, "UTF-16")
    return true
}

ME_SpecialScrollbarScroll_GetPointIdentity(screenX, screenY, ByRef identity) {
    identity := false
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!ME_SpecialScrollbarScroll_GetWindowIdentity(pointHwnd
        , processId, threadId, className))
        return false
    rootHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd
        , "UInt", 2, "Ptr") ; GA_ROOT
    if (!ME_SpecialScrollbarScroll_GetWindowIdentity(rootHwnd
        , rootProcessId, rootThreadId, rootClassName))
        return false
    identity := {PointHwnd: pointHwnd, ProcessId: processId, ThreadId: threadId
        , PointClass: className, RootHwnd: rootHwnd, RootProcessId: rootProcessId
        , RootThreadId: rootThreadId, RootClass: rootClassName}
    return true
}

ME_SpecialScrollbarScroll_RevalidatePoint(screenX, screenY, identity) {
    if (!IsObject(identity)
        || !ME_GetCursorScreenPoint(currentScreenX, currentScreenY)
        || currentScreenX != screenX || currentScreenY != screenY
        || !ME_SpecialScrollbarScroll_GetPointIdentity(currentScreenX
            , currentScreenY, currentIdentity))
        return false
    requiredKeys := ["PointHwnd", "ProcessId", "ThreadId", "PointClass"
        , "RootHwnd", "RootProcessId", "RootThreadId", "RootClass"]
    for _, keyName in requiredKeys {
        if (!identity.HasKey(keyName) || !currentIdentity.HasKey(keyName)
            || !(identity[keyName] == currentIdentity[keyName]))
            return false
    }
    return true
}

ME_SpecialScrollbarScroll_GetParentStatus(elementPtr, ByRef parentPtr) {
    parentPtr := 0
    ownedParentPtr := 0
    try {
        if (!elementPtr)
            return "API_FAILURE"
        walkerPtr := ME_UIA_GetRawViewWalker() ; borrowed
        if (!walkerPtr)
            return "API_FAILURE"
        method := ME_ComMethod(walkerPtr, 3) ; IUIAutomationTreeWalker::GetParentElement
        if (!method)
            return "API_FAILURE"
        hresult := DllCall(method, "Ptr", walkerPtr, "Ptr", elementPtr
            , "PtrP", ownedParentPtr, "Int")
        if (hresult < 0)
            return "API_FAILURE"
        if (!ownedParentPtr)
            return "END_OF_TREE"
        parentPtr := ownedParentPtr
        ownedParentPtr := 0
        return "SUCCESS"
    } catch error {
        return "API_FAILURE"
    } finally {
        if (ownedParentPtr) {
            releasedPtr := ownedParentPtr
            ownedParentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_SpecialScrollbarScroll_GetPatternStatus(elementPtr, patternId
    , ByRef patternPtr) {
    patternPtr := 0
    ownedPatternPtr := 0
    try {
        if (!elementPtr || !ME_IsIntegerString(Trim(patternId)))
            return "API_FAILURE"
        method := ME_ComMethod(elementPtr, 16) ; IUIAutomationElement::GetCurrentPattern
        if (!method)
            return "API_FAILURE"
        hresult := DllCall(method, "Ptr", elementPtr, "Int", patternId + 0
            , "PtrP", ownedPatternPtr, "Int")
        if (hresult < 0)
            return "API_FAILURE"
        if (!ownedPatternPtr)
            return "NOT_SUPPORTED"
        patternPtr := ownedPatternPtr
        ownedPatternPtr := 0
        return "SUCCESS"
    } catch error {
        return "API_FAILURE"
    } finally {
        if (ownedPatternPtr) {
            releasedPtr := ownedPatternPtr
            ownedPatternPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_SpecialScrollbarScroll_GetWindowStyle(hwnd, ByRef style) {
    style := 0
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    DllCall("Kernel32\SetLastError", "UInt", 0)
    if (A_PtrSize = 8)
        style := DllCall("User32\GetWindowLongPtrW", "Ptr", hwnd
            , "Int", -16, "UPtr") ; GWL_STYLE
    else
        style := DllCall("User32\GetWindowLongW", "Ptr", hwnd
            , "Int", -16, "UInt")
    return !(style = 0 && A_LastError != 0)
}

ME_SpecialScrollbarScroll_ReadScrollBarInfo(hwnd, objectId, screenX, screenY
    , ByRef info) {
    info := false
    VarSetCapacity(scrollBarInfo, 60, 0)
    NumPut(60, scrollBarInfo, 0, "UInt")
    if (!DllCall("User32\GetScrollBarInfo", "Ptr", hwnd, "Int", objectId
        , "Ptr", &scrollBarInfo, "Int"))
        return false
    left := NumGet(scrollBarInfo, 4, "Int")
    top := NumGet(scrollBarInfo, 8, "Int")
    right := NumGet(scrollBarInfo, 12, "Int")
    bottom := NumGet(scrollBarInfo, 16, "Int")
    stateFlags := NumGet(scrollBarInfo, 36, "UInt") ; rgstate[0]
    usable := (!(stateFlags & 0x00000001) ; STATE_SYSTEM_UNAVAILABLE
        && !(stateFlags & 0x00008000) ; STATE_SYSTEM_INVISIBLE
        && !(stateFlags & 0x00010000) ; STATE_SYSTEM_OFFSCREEN
        && right > left && bottom > top) ? true : false
    containsPoint := (usable && screenX >= left && screenX < right
        && screenY >= top && screenY < bottom) ? true : false
    info := {Left: left, Top: top, Right: right, Bottom: bottom
        , StateFlags: stateFlags, Usable: usable, ContainsPoint: containsPoint}
    return true
}

ME_SpecialScrollbarScroll_CreateCandidate(lane, axis, screenX, screenY
    , identity, controlHwnd := 0, targetHwnd := 0) {
    if (!IsObject(identity))
        return false
    return {Kind: "SpecialScrollbarScroll", Lane: lane, Axis: axis
        , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount
        , PointHwnd: identity.PointHwnd, ProcessId: identity.ProcessId
        , ThreadId: identity.ThreadId, PointClass: identity.PointClass
        , RootHwnd: identity.RootHwnd, RootProcessId: identity.RootProcessId
        , RootThreadId: identity.RootThreadId, RootClass: identity.RootClass
        , ControlHwnd: controlHwnd, TargetHwnd: targetHwnd}
}

ME_SpecialScrollbarScroll_ResolveClassic(screenX, screenY, identity) {
    if (!IsObject(identity) || !identity.PointHwnd)
        return {Status: "NO_MATCH"}
    pointHwnd := identity.PointHwnd
    if (identity.PointClass == "ScrollBar") {
        if (!DllCall("User32\IsWindowVisible", "Ptr", pointHwnd, "Int")
            || !DllCall("User32\IsWindowEnabled", "Ptr", pointHwnd, "Int")
            || !ME_SpecialScrollbarScroll_GetWindowStyle(pointHwnd, style)
            || (style & 0x0008) || (style & 0x0010)) ; SBS_SIZEBOX / SBS_SIZEGRIP
            return {Status: "BLOCKED"}
        axis := (style & 0x0001) ? "Vertical" : "Horizontal" ; SBS_VERT
        if (!ME_SpecialScrollbarScroll_ReadScrollBarInfo(pointHwnd, -4
            , screenX, screenY, scrollInfo) ; OBJID_CLIENT
            || !IsObject(scrollInfo) || !scrollInfo.Usable || !scrollInfo.ContainsPoint)
            return {Status: "BLOCKED"}
        parentHwnd := DllCall("User32\GetParent", "Ptr", pointHwnd, "Ptr")
        if (!parentHwnd || !DllCall("User32\IsWindow", "Ptr", parentHwnd, "Int")
            || !ME_SpecialScrollbarScroll_GetAxisValue(axis, axisValue)
            || axisValue = 0)
            return {Status: "BLOCKED"}
        candidate := ME_SpecialScrollbarScroll_CreateCandidate("ClassicControl"
            , axis, screenX, screenY, identity, pointHwnd, parentHwnd)
        if (!IsObject(candidate))
            return {Status: "BLOCKED"}
        return {Status: "MATCH", Candidate: candidate}
    }

    if (!ME_SpecialScrollbarScroll_GetWindowStyle(pointHwnd, style))
        return {Status: "BLOCKED"}
    hasVertical := (style & 0x00200000) ? true : false ; WS_VSCROLL
    hasHorizontal := (style & 0x00100000) ? true : false ; WS_HSCROLL
    if (!hasVertical && !hasHorizontal)
        return {Status: "NO_MATCH"}

    verticalMatch := false
    horizontalMatch := false
    if (hasVertical) {
        if (!ME_SpecialScrollbarScroll_ReadScrollBarInfo(pointHwnd, -5
            , screenX, screenY, verticalInfo)) ; OBJID_VSCROLL
            return {Status: "BLOCKED"}
        verticalMatch := (IsObject(verticalInfo) && verticalInfo.Usable
            && verticalInfo.ContainsPoint) ? true : false
    }
    if (hasHorizontal) {
        if (!ME_SpecialScrollbarScroll_ReadScrollBarInfo(pointHwnd, -6
            , screenX, screenY, horizontalInfo)) ; OBJID_HSCROLL
            return {Status: "BLOCKED"}
        horizontalMatch := (IsObject(horizontalInfo) && horizontalInfo.Usable
            && horizontalInfo.ContainsPoint) ? true : false
    }
    if (verticalMatch && horizontalMatch)
        return {Status: "BLOCKED"}
    if (!verticalMatch && !horizontalMatch)
        return {Status: "NO_MATCH"}
    axis := verticalMatch ? "Vertical" : "Horizontal"
    if (!ME_SpecialScrollbarScroll_GetAxisValue(axis, axisValue) || axisValue = 0)
        return {Status: "BLOCKED"}
    candidate := ME_SpecialScrollbarScroll_CreateCandidate("ClassicStandard"
        , axis, screenX, screenY, identity, 0, pointHwnd)
    if (!IsObject(candidate))
        return {Status: "BLOCKED"}
    return {Status: "MATCH", Candidate: candidate}
}

ME_SpecialScrollbarScroll_ReadUiaScrollBarAxis(elementPtr, ByRef axis) {
    axis := ""
    if (!ME_UIA_GetProperty(elementPtr, 30003, controlType))
        return false
    if (controlType != 50014) ; UIA_ScrollBarControlTypeId
        return true
    if (!ME_UIA_GetProperty(elementPtr, 30024, frameworkId)
        || !ME_UIA_GetProperty(elementPtr, 30023, orientation)
        || !ME_UIA_GetProperty(elementPtr, 30010, isEnabled)
        || !ME_UIA_GetProperty(elementPtr, 30022, isOffscreen))
        return false
    if (!(frameworkId == "XAML") || !(isEnabled = 1) || !(isOffscreen = 0))
        return true
    if (orientation = 1)
        axis := "Horizontal"
    else if (orientation = 2)
        axis := "Vertical"
    return true
}

ME_SpecialScrollbarScroll_ResolveUia(screenX, screenY, identity
    , returnPattern := false) {
    global ME_State
    currentPtr := 0
    nextPtr := 0
    matchedScrollBarPtr := 0
    containerPtr := 0
    nextContainerPtr := 0
    patternPtr := 0
    selectedPatternPtr := 0
    try {
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY, false)
        if (!currentPtr)
            return {Status: "BLOCKED"}

        matchCount := 0
        maxScrollBarDepth := ME_State.SpecialScrollbarScroll.ScrollBarMaxDepth
        Loop, % maxScrollBarDepth + 1 {
            if (!ME_SpecialScrollbarScroll_ReadUiaScrollBarAxis(currentPtr, axis))
                return {Status: "BLOCKED"}
            if (axis != "") {
                matchCount += 1
                if (matchCount > 1)
                    return {Status: "BLOCKED"}
                if (!ME_ComAddRef(currentPtr))
                    return {Status: "BLOCKED"}
                matchedScrollBarPtr := currentPtr
                matchedAxis := axis
            }
            if (A_Index > maxScrollBarDepth)
                break
            parentStatus := ME_SpecialScrollbarScroll_GetParentStatus(currentPtr
                , nextPtr)
            if (parentStatus == "API_FAILURE")
                return {Status: "BLOCKED"}
            if (parentStatus == "END_OF_TREE")
                break
            if (!(parentStatus == "SUCCESS") || !nextPtr)
                return {Status: "BLOCKED"}
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
        if (matchCount = 0)
            return {Status: "NO_MATCH"}
        if (!ME_SpecialScrollbarScroll_GetAxisValue(matchedAxis, axisValue)
            || axisValue = 0)
            return {Status: "BLOCKED"}

        parentStatus := ME_SpecialScrollbarScroll_GetParentStatus(matchedScrollBarPtr, containerPtr)
        if (parentStatus == "API_FAILURE")
            return {Status: "BLOCKED"}
        if (parentStatus == "END_OF_TREE")
            return {Status: "BLOCKED"}
        if (!(parentStatus == "SUCCESS") || !containerPtr)
            return {Status: "BLOCKED"}
        containerMatchCount := 0
        maxContainerDepth := ME_State.SpecialScrollbarScroll.ContainerMaxDepth
        Loop, % maxContainerDepth {
            if (!ME_UIA_GetProperty(containerPtr, 30024, frameworkId))
                return {Status: "BLOCKED"}
            if (frameworkId == "XAML") {
                patternStatus := ME_SpecialScrollbarScroll_GetPatternStatus(containerPtr, 10004, patternPtr)
                if (patternStatus == "API_FAILURE")
                    return {Status: "BLOCKED"}
                if (patternStatus == "SUCCESS") {
                    scrollablePropertyId := (matchedAxis == "Vertical") ? 30058 : 30057
                    if (!ME_UIA_GetProperty(containerPtr, scrollablePropertyId
                        , isScrollable))
                        return {Status: "BLOCKED"}
                    if (isScrollable = 1) {
                        containerMatchCount += 1
                        if (containerMatchCount > 1)
                            return {Status: "BLOCKED"}
                        if (returnPattern) {
                            selectedPatternPtr := patternPtr
                            patternPtr := 0
                        }
                    }
                    if (patternPtr) {
                        releasedPtr := patternPtr
                        patternPtr := 0
                        ME_ComRelease(releasedPtr)
                    }
                } else if (!(patternStatus == "NOT_SUPPORTED"))
                    return {Status: "BLOCKED"}
            }
            if (A_Index >= maxContainerDepth)
                break
            parentStatus := ME_SpecialScrollbarScroll_GetParentStatus(containerPtr
                , nextContainerPtr)
            if (parentStatus == "API_FAILURE")
                return {Status: "BLOCKED"}
            if (parentStatus == "END_OF_TREE")
                break
            if (!(parentStatus == "SUCCESS") || !nextContainerPtr)
                return {Status: "BLOCKED"}
            releasedPtr := containerPtr
            containerPtr := 0
            ME_ComRelease(releasedPtr)
            containerPtr := nextContainerPtr
            nextContainerPtr := 0
        }
        if (containerMatchCount != 1
            || (returnPattern && !selectedPatternPtr))
            return {Status: "BLOCKED"}
        candidate := ME_SpecialScrollbarScroll_CreateCandidate("UiaXaml"
            , matchedAxis, screenX, screenY, identity)
        if (!IsObject(candidate))
            return {Status: "BLOCKED"}
        if (!ME_SpecialScrollbarScroll_RevalidatePoint(screenX, screenY, identity))
            return {Status: "BLOCKED"}
        result := {Status: "MATCH", Candidate: candidate}
        if (returnPattern) {
            result.PatternPtr := selectedPatternPtr
            selectedPatternPtr := 0
        }
        return result
    } catch error {
        return {Status: "BLOCKED"}
    } finally {
        if (patternPtr) {
            releasedPtr := patternPtr
            patternPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (selectedPatternPtr) {
            releasedPtr := selectedPatternPtr
            selectedPatternPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (nextContainerPtr) {
            releasedPtr := nextContainerPtr
            nextContainerPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (containerPtr) {
            releasedPtr := containerPtr
            containerPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (matchedScrollBarPtr) {
            releasedPtr := matchedScrollBarPtr
            matchedScrollBarPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_SpecialScrollbarScroll_Resolve(screenX, screenY, returnPattern := false) {
    if (!ME_SpecialScrollbarScroll_GetPointIdentity(screenX, screenY, identity))
        return {Status: "NO_MATCH"}
    classicResult := ME_SpecialScrollbarScroll_ResolveClassic(screenX, screenY, identity)
    if (!IsObject(classicResult) || !classicResult.HasKey("Status"))
        return {Status: "BLOCKED"}
    if (!(classicResult.Status == "NO_MATCH"))
        return classicResult
    return ME_SpecialScrollbarScroll_ResolveUia(screenX, screenY
        , identity, returnPattern)
}

ME_SpecialScrollbarScroll_PrepareTarget() {
    global ME_State
    state := ME_State.SpecialScrollbarScroll
    state.Candidate := false
    try {
        if (!ME_SpecialScrollbarScroll_CanOperate()
            || !ME_GetCursorScreenPoint(screenX, screenY))
            return false
        result := ME_SpecialScrollbarScroll_Resolve(screenX, screenY, false)
        if (!IsObject(result) || !(result.Status == "MATCH")
            || !IsObject(result.Candidate)
            || !ME_SpecialScrollbarScroll_CanOperate())
            return false
        state.Candidate := result.Candidate
        return true
    } catch error {
        state.Candidate := false
        return false
    }
}

ME_SpecialScrollbarScroll_AreCandidatesEqual(first, second) {
    if (!IsObject(first) || !IsObject(second))
        return false
    requiredKeys := ["Kind", "Lane", "Axis", "ScreenX", "ScreenY"
        , "PointHwnd", "ProcessId", "ThreadId", "PointClass"
        , "RootHwnd", "RootProcessId", "RootThreadId", "RootClass"
        , "ControlHwnd", "TargetHwnd"]
    for _, keyName in requiredKeys {
        if (!first.HasKey(keyName) || !second.HasKey(keyName)
            || !(first[keyName] == second[keyName]))
            return false
    }
    return true
}

ME_SpecialScrollbarScroll_PostClassicAction(candidate, direction, stepCount) {
    if (!IsObject(candidate)
        || !(candidate.Lane == "ClassicControl"
            || candidate.Lane == "ClassicStandard")
        || !(candidate.Axis == "Vertical" || candidate.Axis == "Horizontal")
        || !(direction == "Up" || direction == "Down")
        || !ME_SpecialScrollbarScroll_GetAxisValue(candidate.Axis, axisValue)
        || axisValue = 0 || IsObject(stepCount)
        || !ME_IsIntegerString(stepCount) || stepCount < 1)
        return false
    targetHwnd := candidate.TargetHwnd
    if (!targetHwnd || !DllCall("User32\IsWindow", "Ptr", targetHwnd, "Int")
        || !DllCall("User32\IsWindowVisible", "Ptr", targetHwnd, "Int")
        || !DllCall("User32\IsWindowEnabled", "Ptr", targetHwnd, "Int"))
        return false
    if (candidate.Lane == "ClassicControl") {
        controlHwnd := candidate.ControlHwnd
        if (!controlHwnd || !DllCall("User32\IsWindow", "Ptr", controlHwnd, "Int")
            || !DllCall("User32\IsWindowVisible", "Ptr", controlHwnd, "Int")
            || !DllCall("User32\IsWindowEnabled", "Ptr", controlHwnd, "Int")
            || DllCall("User32\GetParent", "Ptr", controlHwnd, "Ptr") != targetHwnd)
            return false
        messageLParam := controlHwnd
    } else {
        messageLParam := 0
    }
    messageId := (candidate.Axis == "Vertical") ? 0x0115 : 0x0114
    if (axisValue > 0) {
        requestCode := (direction == "Up") ? 0 : 1
        repeatCount := stepCount * axisValue
    } else if (axisValue = -1) {
        requestCode := (direction == "Up") ? 2 : 3
        repeatCount := stepCount
    } else {
        requestCode := (direction == "Up") ? 6 : 7
        repeatCount := stepCount
    }
    successCount := 0
    Loop, % repeatCount {
        try {
            posted := DllCall("User32\PostMessageW", "Ptr", targetHwnd
                , "UInt", messageId, "Ptr", requestCode, "Ptr", messageLParam, "Int")
        } catch error {
            return (successCount > 0) ? true : false
        }
        if (!posted)
            return (successCount > 0) ? true : false
        successCount += 1
    }
    return (successCount > 0) ? true : false
}

ME_SpecialScrollbarScroll_InvokeUiaAction(patternPtr, axis, direction, stepCount) {
    if (!patternPtr || !(axis == "Vertical" || axis == "Horizontal")
        || !(direction == "Up" || direction == "Down")
        || IsObject(stepCount) || !ME_IsIntegerString(stepCount) || stepCount < 1
        || !ME_SpecialScrollbarScroll_GetAxisValue(axis, axisValue)
        || axisValue = 0)
        return false
    successCount := 0
    if (axisValue = -2) {
        method := ME_ComMethod(patternPtr, 4) ; IUIAutomationScrollPattern::SetScrollPercent
        if (!method)
            return false
        horizontalPercent := -1.0
        verticalPercent := -1.0
        if (axis == "Horizontal")
            horizontalPercent := (direction == "Up") ? 0.0 : 100.0
        else
            verticalPercent := (direction == "Up") ? 0.0 : 100.0
        Loop, % stepCount {
            try {
                hresult := DllCall(method, "Ptr", patternPtr
                    , "Double", horizontalPercent, "Double", verticalPercent, "Int")
            } catch error {
                return (successCount > 0) ? true : false
            }
            if (hresult < 0)
                return (successCount > 0) ? true : false
            successCount += 1
        }
        return (successCount > 0) ? true : false
    }

    method := ME_ComMethod(patternPtr, 3) ; IUIAutomationScrollPattern::Scroll
    if (!method)
        return false
    if (axisValue > 0) {
        amount := (direction == "Up") ? 1 : 4 ; SmallDecrement / SmallIncrement
        repeatCount := stepCount * axisValue
    } else {
        amount := (direction == "Up") ? 0 : 3 ; LargeDecrement / LargeIncrement
        repeatCount := stepCount
    }
    horizontalAmount := (axis == "Horizontal") ? amount : 2 ; NoAmount
    verticalAmount := (axis == "Vertical") ? amount : 2
    Loop, % repeatCount {
        try {
            hresult := DllCall(method, "Ptr", patternPtr
                , "Int", horizontalAmount, "Int", verticalAmount, "Int")
        } catch error {
            return (successCount > 0) ? true : false
        }
        if (hresult < 0)
            return (successCount > 0) ? true : false
        successCount += 1
    }
    return (successCount > 0) ? true : false
}

ME_SpecialScrollbarScroll_HandleWheel(input) {
    global ME_State
    state := ME_State.SpecialScrollbarScroll
    patternPtr := 0
    try {
        if (!IsObject(input) || !ME_SpecialScrollbarScroll_CanOperate()
            || !(input.Direction == "Up" || input.Direction == "Down")
            || !input.HasKey("Steps") || IsObject(input.Steps)
            || !ME_IsIntegerString(input.Steps) || input.Steps < 1)
            return false
        if (!IsObject(state.Candidate)) {
            if (!ME_SpecialScrollbarScroll_PrepareTarget())
                return false
        }
        candidate := state.Candidate
        state.Candidate := false
        if (!IsObject(candidate) || !(candidate.Kind == "SpecialScrollbarScroll")
            || !candidate.HasKey("Tick") || !candidate.HasKey("ScreenX")
            || !candidate.HasKey("ScreenY"))
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > state.CandidateLifetimeMs
            || !ME_GetCursorScreenPoint(screenX, screenY)
            || screenX != candidate.ScreenX || screenY != candidate.ScreenY
            || !ME_SpecialScrollbarScroll_CanOperate())
            return false

        freshResult := ME_SpecialScrollbarScroll_Resolve(screenX, screenY, true)
        if (IsObject(freshResult) && freshResult.HasKey("PatternPtr")
            && freshResult.PatternPtr) {
            patternPtr := freshResult.PatternPtr
            freshResult.PatternPtr := 0
        }
        if (!IsObject(freshResult) || !(freshResult.Status == "MATCH")
            || !IsObject(freshResult.Candidate)
            || !ME_SpecialScrollbarScroll_AreCandidatesEqual(candidate
                , freshResult.Candidate)
            || !ME_SpecialScrollbarScroll_CanOperate())
            return false
        if (!ME_SpecialScrollbarScroll_RevalidatePoint(candidate.ScreenX
            , candidate.ScreenY, candidate))
            return false
        direction := input.Direction
        stepCount := input.Steps
        if (candidate.Lane == "UiaXaml") {
            if (!patternPtr)
                return false
            return ME_SpecialScrollbarScroll_InvokeUiaAction(patternPtr
                , candidate.Axis, direction, stepCount)
        }
        return ME_SpecialScrollbarScroll_PostClassicAction(candidate
            , direction, stepCount)
    } catch error {
        return false
    } finally {
        if (patternPtr) {
            releasedPtr := patternPtr
            patternPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_SpecialScrollbarScroll_Cleanup() {
    global ME_State
    state := ME_State.SpecialScrollbarScroll
    state.CleanupStarted := true
    state.Candidate := false
    state.Initialized := false
}

; -----------------------------------------------------------------------------
; BrowserDragScroll (v1.1.0: browser sidebar / Explorer right-pane drag + vertical wheel)
; -----------------------------------------------------------------------------

ME_InitializeBrowserDragScroll() {
    global ME_Config, ME_State
    state := ME_State.BrowserDragScroll
    if (state.Initialized)
        return true
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false

    state.Initialized := true
    state.Candidate := false
    if (!ME_Config.EnableFunction.BrowserDragScroll || ME_MouseGestureL_IsEditMode())
        return true
    if (!ME_InitializeWheelInput()) {
        state.Initialized := false
        return false
    }
    return true
}

ME_BrowserDragScroll_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.BrowserDragScroll
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.EnableFunction.BrowserDragScroll && ME_CanRouteMouseInput()
        && ME_State.SyntheticInputDepth = 0 && !ME_MouseGestureL_IsEditMode()) ? true : false
}

ME_BrowserDragScroll_IsPhysicalKeyDown(virtualKey) {
    keyState := DllCall("User32\GetAsyncKeyState", "Int", virtualKey, "Short")
    return ((keyState & 0x8000) != 0) ? true : false
}

ME_BrowserDragScroll_HasExactButtonState() {
    if (!ME_BrowserDragScroll_IsPhysicalKeyDown(0x01)) ; VK_LBUTTON
        return false
    ; RButton/MButton/XButton1/XButton2 and Shift/Ctrl/Alt/LWin/RWin.
    for _, virtualKey in [0x02, 0x04, 0x05, 0x06, 0x10, 0x11, 0x12, 0x5B, 0x5C]
        if (ME_BrowserDragScroll_IsPhysicalKeyDown(virtualKey))
            return false
    return true
}

ME_BrowserDragScroll_GetGuiWindows(threadId, ByRef activeHwnd
    , ByRef focusHwnd, ByRef captureHwnd) {
    activeHwnd := 0
    focusHwnd := 0
    captureHwnd := 0
    if (!threadId)
        return false

    guiInfoSize := 8 + (6 * A_PtrSize) + 16
    VarSetCapacity(guiInfo, guiInfoSize, 0)
    NumPut(guiInfoSize, guiInfo, 0, "UInt")
    if (!DllCall("User32\GetGUIThreadInfo", "UInt", threadId
        , "Ptr", &guiInfo, "Int"))
        return false

    activeHwnd := NumGet(guiInfo, 8 + (0 * A_PtrSize), "Ptr")
    focusHwnd := NumGet(guiInfo, 8 + (1 * A_PtrSize), "Ptr")
    captureHwnd := NumGet(guiInfo, 8 + (2 * A_PtrSize), "Ptr")
    return true
}

ME_BrowserDragScroll_GetProcessName(processId, ByRef processName) {
    processName := ""
    if (!processId)
        return false

    processHandle := DllCall("Kernel32\OpenProcess", "UInt", 0x1000
        , "Int", false, "UInt", processId, "Ptr") ; PROCESS_QUERY_LIMITED_INFORMATION
    if (!processHandle)
        return false

    characterCapacity := 32768
    VarSetCapacity(pathBuffer, characterCapacity * 2, 0)
    characterCount := characterCapacity
    querySucceeded := DllCall("Kernel32\QueryFullProcessImageNameW"
        , "Ptr", processHandle, "UInt", 0, "Ptr", &pathBuffer
        , "UIntP", characterCount, "Int")
    DllCall("Kernel32\CloseHandle", "Ptr", processHandle, "Int")
    if (!querySucceeded || characterCount <= 0 || characterCount >= characterCapacity)
        return false

    imagePath := StrGet(&pathBuffer, characterCount, "UTF-16")
    if (imagePath = "")
        return false
    SplitPath, imagePath, processName
    return (processName != "") ? true : false
}

ME_BrowserDragScroll_IsTargetEnabled(processName) {
    global ME_Config
    if (processName == "firefox.exe")
        return ME_Config.BrowserDragScroll.Firefox ? true : false
    if (processName == "chrome.exe")
        return ME_Config.BrowserDragScroll.Chrome ? true : false
    if (processName == "msedge.exe")
        return ME_Config.BrowserDragScroll.Edge ? true : false
    if (processName == "explorer.exe")
        return ME_Config.BrowserDragScroll.Explorer ? true : false
    return false
}

ME_BrowserDragScroll_GetExplorerEligibleSnapshot(foregroundHwnd
    , foregroundProcessId, foregroundThreadId, foregroundClass
    , foregroundProcess) {
    if (!(foregroundProcess == "explorer.exe")
        || !(foregroundClass == "CabinetWClass")
        || !ME_BrowserDragScroll_GetGuiWindows(foregroundThreadId
            , activeHwnd, focusHwnd, captureHwnd)
        || !focusHwnd)
        return false

    if (!ME_AlwaysOnTop_GetWindowIdentity(focusHwnd
            , focusProcessId, focusThreadId, focusClass)
        || foregroundProcessId != focusProcessId
        || !(focusClass == "DirectUIHWND"))
        return false

    rootHwnd := DllCall("User32\GetAncestor", "Ptr", foregroundHwnd
        , "UInt", 2, "Ptr") ; GA_ROOT
    focusRootHwnd := DllCall("User32\GetAncestor", "Ptr", focusHwnd
        , "UInt", 2, "Ptr") ; GA_ROOT
    parentHwnd := DllCall("User32\GetParent", "Ptr", focusHwnd, "Ptr")
    if (!rootHwnd || rootHwnd != foregroundHwnd || focusRootHwnd != rootHwnd
        || !ME_AlwaysOnTop_GetWindowIdentity(rootHwnd
            , rootProcessId, rootThreadId, rootClass)
        || rootProcessId != foregroundProcessId
        || !(rootClass == "CabinetWClass")
        || !ME_AlwaysOnTop_GetWindowIdentity(parentHwnd
            , parentProcessId, parentThreadId, parentClass)
        || parentProcessId != foregroundProcessId
        || !(parentClass == "SHELLDLL_DefView"))
        return false

    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || pointHwnd != focusHwnd
        || !ME_AlwaysOnTop_GetWindowIdentity(pointHwnd
            , pointProcessId, pointThreadId, pointClass)
        || pointProcessId != foregroundProcessId
        || !(pointClass == "DirectUIHWND")
        || DllCall("User32\GetAncestor", "Ptr", pointHwnd
            , "UInt", 2, "Ptr") != rootHwnd)
        return false

    captureProcessId := 0
    captureThreadId := 0
    captureClass := ""
    if (captureHwnd && !ME_AlwaysOnTop_GetWindowIdentity(captureHwnd
            , captureProcessId, captureThreadId, captureClass))
        return false

    return {BrowserProcess: foregroundProcess
        , ForegroundHwnd: foregroundHwnd, ForegroundProcessId: foregroundProcessId
        , ForegroundThreadId: foregroundThreadId, ForegroundClass: foregroundClass
        , FocusHwnd: focusHwnd, FocusProcessId: focusProcessId
        , FocusThreadId: focusThreadId, FocusClass: focusClass
        , CaptureHwnd: captureHwnd, CaptureProcessId: captureProcessId
        , CaptureThreadId: captureThreadId, CaptureClass: captureClass
        , PointHwnd: pointHwnd, PointProcessId: pointProcessId
        , PointThreadId: pointThreadId, PointClass: pointClass
        , ScreenX: screenX, ScreenY: screenY}
}

ME_BrowserDragScroll_GetEligibleSnapshot() {
    if (!ME_BrowserDragScroll_CanOperate()
        || !ME_BrowserDragScroll_HasExactButtonState())
        return false

    foregroundHwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd
        || !ME_AlwaysOnTop_GetWindowIdentity(foregroundHwnd
            , foregroundProcessId, foregroundThreadId, foregroundClass))
        return false

    if (!ME_BrowserDragScroll_GetProcessName(foregroundProcessId
            , foregroundProcess))
        return false
    if (!ME_BrowserDragScroll_IsTargetEnabled(foregroundProcess))
        return false
    if (foregroundProcess == "explorer.exe")
        return ME_BrowserDragScroll_GetExplorerEligibleSnapshot(foregroundHwnd
            , foregroundProcessId, foregroundThreadId, foregroundClass
            , foregroundProcess)

    if (!ME_BrowserDragScroll_GetGuiWindows(foregroundThreadId
            , activeHwnd, focusHwnd, captureHwnd)
        || !focusHwnd || !captureHwnd || foregroundHwnd != focusHwnd)
        return false

    if (!ME_AlwaysOnTop_GetWindowIdentity(focusHwnd
            , focusProcessId, focusThreadId, focusClass)
        || !ME_AlwaysOnTop_GetWindowIdentity(captureHwnd
            , captureProcessId, captureThreadId, captureClass)
        || foregroundProcessId != focusProcessId
        || foregroundProcessId != captureProcessId)
        return false

    if (!ME_BrowserDragScroll_GetProcessName(foregroundProcessId, foregroundProcess)
        || !ME_BrowserDragScroll_GetProcessName(focusProcessId, focusProcess)
        || !ME_BrowserDragScroll_GetProcessName(captureProcessId, captureProcess))
        return false

    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd
        || !ME_AlwaysOnTop_GetWindowIdentity(pointHwnd
            , pointProcessId, pointThreadId, pointClass)
        || pointProcessId != foregroundProcessId
        || !ME_BrowserDragScroll_GetProcessName(pointProcessId, pointProcess))
        return false

    if (!(foregroundProcess == focusProcess)
        || !(foregroundProcess == captureProcess)
        || !(foregroundProcess == pointProcess))
        return false

    if (foregroundProcess == "chrome.exe" || foregroundProcess == "msedge.exe") {
        if (!(foregroundClass == "Chrome_WidgetWin_1")
            || !(focusClass == "Chrome_WidgetWin_1")
            || !(captureClass == "CLIPBRDWNDCLASS")
            || !(pointClass == "Chrome_RenderWidgetHostHWND"))
            return false
    } else if (foregroundProcess == "firefox.exe") {
        if (!(foregroundClass == "MozillaWindowClass")
            || !(focusClass == "MozillaWindowClass")
            || !(captureClass == "CLIPBRDWNDCLASS")
            || !(pointClass == "MozillaWindowClass"))
            return false
    } else {
        return false
    }

    return {BrowserProcess: foregroundProcess
        , ForegroundHwnd: foregroundHwnd, ForegroundProcessId: foregroundProcessId
        , ForegroundThreadId: foregroundThreadId, ForegroundClass: foregroundClass
        , FocusHwnd: focusHwnd, FocusProcessId: focusProcessId
        , FocusThreadId: focusThreadId, FocusClass: focusClass
        , CaptureHwnd: captureHwnd, CaptureProcessId: captureProcessId
        , CaptureThreadId: captureThreadId, CaptureClass: captureClass
        , PointHwnd: pointHwnd, PointProcessId: pointProcessId
        , PointThreadId: pointThreadId, PointClass: pointClass
        , ScreenX: screenX, ScreenY: screenY}
}

ME_BrowserDragScroll_PrepareTarget() {
    global ME_State
    state := ME_State.BrowserDragScroll
    state.Candidate := false
    try {
        snapshot := ME_BrowserDragScroll_GetEligibleSnapshot()
        if (!IsObject(snapshot))
            return false
        snapshot.Kind := "BrowserDragScroll"
        snapshot.Tick := A_TickCount
        state.Candidate := snapshot
        return true
    } catch error {
        state.Candidate := false
        return false
    }
}

ME_BrowserDragScroll_AreSnapshotsEqual(candidate, current) {
    if (!IsObject(candidate) || !IsObject(current))
        return false
    return (candidate.BrowserProcess == current.BrowserProcess
        && candidate.ForegroundHwnd = current.ForegroundHwnd
        && candidate.ForegroundProcessId = current.ForegroundProcessId
        && candidate.ForegroundThreadId = current.ForegroundThreadId
        && candidate.ForegroundClass == current.ForegroundClass
        && candidate.FocusHwnd = current.FocusHwnd
        && candidate.FocusProcessId = current.FocusProcessId
        && candidate.FocusThreadId = current.FocusThreadId
        && candidate.FocusClass == current.FocusClass
        && candidate.CaptureHwnd = current.CaptureHwnd
        && candidate.CaptureProcessId = current.CaptureProcessId
        && candidate.CaptureThreadId = current.CaptureThreadId
        && candidate.CaptureClass == current.CaptureClass
        && candidate.PointHwnd = current.PointHwnd
        && candidate.PointProcessId = current.PointProcessId
        && candidate.PointThreadId = current.PointThreadId
        && candidate.PointClass == current.PointClass) ? true : false
}

ME_BrowserDragScroll_IsCandidateValid(candidate, ByRef currentSnapshot) {
    global ME_State
    currentSnapshot := false
    if (!IsObject(candidate) || !(candidate.Kind == "BrowserDragScroll")
        || !candidate.HasKey("Tick") || !ME_BrowserDragScroll_CanOperate())
        return false

    elapsed := A_TickCount - candidate.Tick
    if (elapsed < 0)
        elapsed += 0x100000000
    if (elapsed > ME_State.BrowserDragScroll.CandidateLifetimeMs)
        return false

    currentSnapshot := ME_BrowserDragScroll_GetEligibleSnapshot()
    if (!ME_BrowserDragScroll_AreSnapshotsEqual(candidate, currentSnapshot))
        return false

    elapsed := A_TickCount - candidate.Tick
    if (elapsed < 0)
        elapsed += 0x100000000
    return (elapsed <= ME_State.BrowserDragScroll.CandidateLifetimeMs
        && ME_BrowserDragScroll_CanOperate()) ? true : false
}

ME_BrowserDragScroll_RevalidateInputState(snapshot, ByRef screenX, ByRef screenY) {
    screenX := 0
    screenY := 0
    if (!IsObject(snapshot) || !ME_BrowserDragScroll_CanOperate()
        || !ME_BrowserDragScroll_HasExactButtonState()
        || DllCall("User32\GetForegroundWindow", "Ptr") != snapshot.ForegroundHwnd
        || !ME_BrowserDragScroll_GetGuiWindows(snapshot.ForegroundThreadId
            , activeHwnd, focusHwnd, captureHwnd)
        || focusHwnd != snapshot.FocusHwnd || captureHwnd != snapshot.CaptureHwnd
        || !ME_GetCursorScreenPoint(screenX, screenY)
        || ME_WindowFromScreenPoint(screenX, screenY) != snapshot.PointHwnd)
        return false
    return true
}

ME_BrowserDragScroll_HandleWheel(input) {
    global ME_State
    state := ME_State.BrowserDragScroll
    ownsInput := IsObject(state.Candidate)
    if (!ownsInput)
        return false

    try {
        candidate := state.Candidate
        state.Candidate := false
        if (!IsObject(input) || !input.HasKey("Direction") || !input.HasKey("Steps")
            || !(input.Direction == "Up" || input.Direction == "Down")
            || IsObject(input.Steps) || !ME_IsIntegerString(input.Steps)
            || input.Steps != 1)
            return true
        if (!ME_BrowserDragScroll_IsCandidateValid(candidate, currentSnapshot)
            || !ME_BrowserDragScroll_RevalidateInputState(currentSnapshot
                , screenX, screenY))
            return true

        wheelWParam := (input.Direction == "Up") ? 0x00780001 : 0xFF880001
        packedCoordinates := (screenX & 0xFFFF) | ((screenY & 0xFFFF) << 16)
        DllCall("User32\SendNotifyMessageW", "Ptr", currentSnapshot.FocusHwnd
            , "UInt", 0x020A, "UPtr", wheelWParam, "UPtr", packedCoordinates, "Int")
        return true
    } catch error {
        state.Candidate := false
        return true
    }
}

ME_BrowserDragScroll_Cleanup() {
    global ME_State
    state := ME_State.BrowserDragScroll
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    state.Candidate := false
    state.Initialized := false
}

; -----------------------------------------------------------------------------
; Taskbar (Phase 3A: StartWheel / Phase 3B: TaskButtonWheel)
; -----------------------------------------------------------------------------

ME_InitializeTaskbar() {
    global ME_Config, ME_State
    state := ME_State.Taskbar
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false
    if (state.Initialized)
        return true
    state.Initialized := true
    if (!ME_Config.EnableFunction.Taskbar || ME_MouseGestureL_IsEditMode())
        return true
    ; StartWheel/TaskButtonWheelの既存条件だけで共通Wheelを登録する。
    if (ME_Config.Taskbar.StartWheel || ME_Config.Taskbar.TaskButtonWheel) {
        if (!ME_InitializeWheelInput()) {
            state.Initialized := false
            return false
        }
    }
    ; 専用hotkeyの失敗は新機能だけをfail closedにし、既存Wheelを維持する。
    if (ME_Config.Taskbar.TaskButtonMiddleClick)
        ME_Taskbar_InitializeMiddleClick()
    return true
}

ME_Taskbar_InitializeMiddleClick() {
    global ME_Config, ME_State
    state := ME_State.Taskbar
    if (state.MiddleClickRegistered)
        return true
    if (!state.Initialized || state.CleanupStarted || ME_State.CleanupStarted
        || !ME_Config.EnableFunction.Taskbar || !ME_Config.Taskbar.TaskButtonMiddleClick
        || ME_MouseGestureL_IsEditMode())
        return false

    state.MiddleClickCriterionCallback := Func("ME_Taskbar_ShouldCaptureMiddleClick")
    state.MiddleClickCallback := Func("ME_Taskbar_OnMiddleClick")
    criterionCallback := state.MiddleClickCriterionCallback
    middleClickCallback := state.MiddleClickCallback
    middleClickHotkey := state.MiddleClickHotkeyName
    Hotkey, If, % criterionCallback
    Hotkey, % middleClickHotkey, % middleClickCallback, On UseErrorLevel
    registrationFailed := ErrorLevel ? true : false
    Hotkey, If
    if (registrationFailed) {
        state.MiddleClickCriterionCallback := false
        state.MiddleClickCallback := false
        state.MiddleClickCandidate := false
        return false
    }
    state.MiddleClickRegistered := true
    return true
}

ME_Taskbar_CanOperate(kind := "Start") {
    global ME_Config, ME_State
    state := ME_State.Taskbar
    if (!state.Initialized || state.CleanupStarted || !ME_Config.EnableFunction.Taskbar
        || !ME_CanRouteMouseInput() || ME_State.SyntheticInputDepth != 0)
        return false
    if (kind == "Start")
        return ME_Config.Taskbar.StartWheel ? true : false
    if (kind == "TaskButtonProbe")
        return ME_Config.Taskbar.TaskButtonWheel ? true : false
    if (kind == "TaskButtonMiddleClick")
        return ME_Config.Taskbar.TaskButtonMiddleClick ? true : false
    if (kind == "Any")
        return (ME_Config.Taskbar.StartWheel || ME_Config.Taskbar.TaskButtonWheel) ? true : false
    return false
}

ME_Taskbar_GetRootAtPoint(screenX, screenY, ByRef rootHwnd, ByRef rootClass) {
    rootHwnd := 0
    rootClass := ""
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd)
        return false
    hwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    VarSetCapacity(classBuffer, 512, 0)
    classLength := DllCall("User32\GetClassNameW", "Ptr", hwnd
        , "Ptr", &classBuffer, "Int", 256, "Int")
    if (classLength <= 0)
        return false
    className := StrGet(&classBuffer, classLength, "UTF-16")
    if (!(className == "Shell_TrayWnd" || className == "Shell_SecondaryTrayWnd"))
        return false
    rootHwnd := hwnd
    rootClass := className
    return true
}

ME_Taskbar_IsStartAtPoint(screenX, screenY, ByRef rootHwnd, ByRef rootClass) {
    global ME_State
    ; Win32 root確認を必ず先に行い、taskbar外ではUIAを呼ばない。
    if (!ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass))
        return false
    currentPtr := 0
    nextPtr := 0
    depth := 0
    maxDepth := ME_State.Taskbar.AncestryMaxDepth
    try {
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY)
        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType)
                || !ME_UIA_GetProperty(currentPtr, 30011, automationId))
                return false
            if (controlType = 50000 && automationId == "StartButton") {
                ; UIA問い合わせ中のcursor移動やrootの変化もfail closedにする。
                return (ME_GetCursorScreenPoint(currentX, currentY)
                    && currentX = screenX && currentY = screenY
                    && ME_Taskbar_GetRootAtPoint(currentX, currentY, currentRoot, currentClass)
                    && currentRoot = rootHwnd && currentClass == rootClass) ? true : false
            }
            if (depth >= maxDepth)
                break
            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } catch error {
        return false
    } finally {
        ; ElementFromPoint/GetParentの呼出元所有参照だけを各1回解放する。
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_Taskbar_ReadProbeProperty(elementPtr, propertyId, ByRef available) {
    available := false
    try {
        if (!ME_UIA_GetProperty(elementPtr, propertyId, value) || IsObject(value))
            return "<unavailable>"
        available := true
        return value
    } catch error {
        return "<unavailable>"
    }
}

ME_Taskbar_IsTaskButtonClassName(className) {
    if (IsObject(className) || className == "")
        return false
    if (className == "Taskbar.TaskListButtonAutomationPeer" || className == "Taskbar.TaskListButton")
        return true
    suffix := "TaskListButtonAutomationPeer"
    nameLength := StrLen(className)
    suffixLength := StrLen(suffix)
    return (nameLength >= suffixLength
        && SubStr(className, nameLength - suffixLength + 1) == suffix) ? true : false
}

ME_Taskbar_GetTaskButtonIdentityAtPoint(screenX, screenY, useCache := true) {
    global ME_State
    ; taskbar外ではUIAを開始しない。Start判定はPrepareTarget側で先に行う。
    if (!ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass))
        return false
    currentPtr := 0
    nextPtr := 0
    depth := 0
    maxDepth := ME_State.Taskbar.AncestryMaxDepth
    try {
        currentPtr := ME_UIA_ElementFromPoint(screenX, screenY, useCache)
        while (currentPtr && depth < maxDepth) {
            depth += 1
            if (!ME_UIA_GetProperty(currentPtr, 30003, controlType))
                return false
            if (controlType = 50000) {
                if (!ME_UIA_GetProperty(currentPtr, 30012, className))
                    return false
                if (ME_Taskbar_IsTaskButtonClassName(className)) {
                    automationId := ME_Taskbar_ReadProbeProperty(currentPtr, 30011, automationIdAvailable)
                    if (!automationIdAvailable)
                        return false
                    taskAppId := ME_Taskbar_ParseTaskAppId(automationId)
                    if (taskAppId == "")
                        return false
                    ; 識別直後に時刻を保存。capture/validationでは3 propertyだけを読む。
                    candidate := {Kind: "TaskButtonProbe", TaskbarHwnd: rootHwnd
                        , TaskbarClass: rootClass, ScreenX: screenX, ScreenY: screenY
                        , Tick: A_TickCount, ControlType: controlType, ClassName: className
                        , AutomationId: automationId, TaskAppId: taskAppId}
                    ; property取得中のcursor移動/root変化は診断でもfail closed。
                    if (!ME_GetCursorScreenPoint(currentX, currentY)
                        || currentX != screenX || currentY != screenY
                        || !ME_Taskbar_GetRootAtPoint(currentX, currentY, currentRoot, currentClass)
                        || currentRoot != rootHwnd || !(currentClass == rootClass))
                        return false
                    return candidate ; 全フィールドscalar。elementの所有参照はfinallyで解放。
                }
            }
            if (depth >= maxDepth)
                break
            nextPtr := ME_UIA_GetParent(currentPtr)
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
            currentPtr := nextPtr
            nextPtr := 0
        }
    } catch error {
        return false
    } finally {
        if (nextPtr) {
            releasedPtr := nextPtr
            nextPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (currentPtr) {
            releasedPtr := currentPtr
            currentPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
    return false
}

ME_Taskbar_IsTaskButtonProbeCandidateValid(candidate) {
    global ME_State
    try {
        if (!IsObject(candidate) || !(candidate.Kind == "TaskButtonProbe")
            || !candidate.HasKey("Tick") || !candidate.TaskbarHwnd
            || !ME_Taskbar_AreAppIdsEqual(candidate.TaskAppId, ME_Taskbar_ParseTaskAppId(candidate.AutomationId))
            || !ME_Taskbar_CanOperate("TaskButtonProbe"))
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.Taskbar.TaskButtonProbeCandidateLifetimeMs
            || !DllCall("User32\IsWindow", "Ptr", candidate.TaskbarHwnd, "Int"))
            return false
        if (!ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass)
            || rootHwnd != candidate.TaskbarHwnd || !(rootClass == candidate.TaskbarClass))
            return false
        ; handlerではfresh ElementFromPointで同じ識別条件を再評価する。
        current := ME_Taskbar_GetTaskButtonIdentityAtPoint(screenX, screenY, false)
        if (!IsObject(current) || current.TaskbarHwnd != candidate.TaskbarHwnd
            || !(current.TaskbarClass == candidate.TaskbarClass)
            || current.ControlType != candidate.ControlType
            || !ME_Taskbar_IsTaskButtonClassName(current.ClassName)
            || !(current.ClassName == candidate.ClassName)
            || !ME_Taskbar_AreAppIdsEqual(current.TaskAppId, candidate.TaskAppId)
            || !ME_Taskbar_CanOperate("TaskButtonProbe"))
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.Taskbar.TaskButtonProbeCandidateLifetimeMs)
            return false
        return true
    } catch error {
        return false
    }
}

ME_Taskbar_IsMiddleClickCandidateValid(candidate) {
    global ME_State
    try {
        if (!IsObject(candidate) || !(candidate.Kind == "TaskButtonProbe")
            || !candidate.HasKey("Tick") || !candidate.TaskbarHwnd
            || !ME_Taskbar_AreAppIdsEqual(candidate.TaskAppId, ME_Taskbar_ParseTaskAppId(candidate.AutomationId))
            || !ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.Taskbar.TaskButtonProbeCandidateLifetimeMs
            || !DllCall("User32\IsWindow", "Ptr", candidate.TaskbarHwnd, "Int"))
            return false
        if (!ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass)
            || rootHwnd != candidate.TaskbarHwnd || !(rootClass == candidate.TaskbarClass))
            return false
        ; MiddleClick handlerでもfresh ElementFromPointで同じTaskButtonを再識別する。
        current := ME_Taskbar_GetTaskButtonIdentityAtPoint(screenX, screenY, false)
        if (!IsObject(current) || current.TaskbarHwnd != candidate.TaskbarHwnd
            || !(current.TaskbarClass == candidate.TaskbarClass)
            || current.ControlType != candidate.ControlType
            || !ME_Taskbar_IsTaskButtonClassName(current.ClassName)
            || !(current.ClassName == candidate.ClassName)
            || !ME_Taskbar_AreAppIdsEqual(current.TaskAppId, candidate.TaskAppId)
            || !ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        return (elapsed <= ME_State.Taskbar.TaskButtonProbeCandidateLifetimeMs
            && ME_Taskbar_CanOperate("TaskButtonMiddleClick")) ? true : false
    } catch error {
        return false
    }
}

ME_Taskbar_ShouldCaptureMiddleClick() {
    global ME_State
    state := ME_State.Taskbar
    state.MiddleClickCandidate := false
    try {
        if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick")
            || !ME_GetCursorScreenPoint(screenX, screenY))
            return false
        candidate := ME_Taskbar_GetTaskButtonIdentityAtPoint(screenX, screenY)
        if (!IsObject(candidate) || !ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
            return false
        state.MiddleClickCandidate := candidate
        return true
    } catch error {
        state.MiddleClickCandidate := false
        return false
    }
}

ME_Taskbar_GetMiddleClickCandidateStates(result) {
    try {
        if (!IsObject(result) || !result.NativeAvailable
            || !(result.Resolution == "AMBIGUOUS")
            || IsObject(result.MatchCount) || !ME_IsIntegerString(result.MatchCount)
            || result.MatchCount <= 1
            || !result.HasKey("CandidateHwnds") || !IsObject(result.CandidateHwnds)
            || result.CandidateHwnds.MaxIndex() != result.MatchCount)
            return false

        states := []
        seen := {}
        expectedIndex := 0
        for index, hwnd in result.CandidateHwnds {
            expectedIndex += 1
            ; 欠落・余分なkey・重複を含む不整合集合はClose開始前に全体拒否する。
            if (index != expectedIndex || !ME_Taskbar_IsWindowHandleValue(hwnd)
                || seen.HasKey(hwnd) || !ME_Taskbar_CanOperate("TaskButtonMiddleClick")
                || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
                || !ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className))
                return false
            WinGet, minMax, MinMax, ahk_id %hwnd%
            if (StrLen(minMax) = 0 || !(minMax = -1 || minMax = 0 || minMax = 1))
                return false
            ; 読取後もsame HWND identityと安全条件が維持された候補だけを保存する。
            if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick")
                || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
                || !ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId
                    , currentThreadId, currentClassName)
                || currentProcessId != processId || currentThreadId != threadId
                || !(currentClassName == className))
                return false
            seen[hwnd] := true
            states.Push({Hwnd: hwnd, MinMax: minMax, ProcessId: processId
                , ThreadId: threadId, ClassName: className})
        }
        if (expectedIndex != result.MatchCount
            || !ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
            return false
        return states ; このMiddleClick処理中だけ使用し、global stateへ保存しない。
    } catch error {
        return false
    }
}

ME_Taskbar_SelectMiddleClickMultiWindowTarget(states) {
    if (!IsObject(states) || states.MaxIndex() < 2)
        return false
    for _, candidateState in states {
        if (candidateState.MinMax != -1)
            return candidateState ; CandidateHwndsのZ-orderで最初のvisible window。
    }
    return states[1] ; 全件minimizedの場合だけfront-most candidateを選ぶ。
}

ME_Taskbar_IsMiddleClickWindowStateCurrent(candidateState) {
    try {
        if (!IsObject(candidateState) || !candidateState.Hwnd
            || !candidateState.ProcessId || !candidateState.ThreadId
            || candidateState.ClassName == ""
            || !ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
            return false
        hwnd := candidateState.Hwnd
        if (!DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            || !ME_Taskbar_IsSafeTaskWindow(hwnd)
            || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId
                , currentThreadId, currentClassName)
            || currentProcessId != candidateState.ProcessId
            || currentThreadId != candidateState.ThreadId
            || !(currentClassName == candidateState.ClassName))
            return false
        return (ME_Taskbar_CanOperate("TaskButtonMiddleClick")
            && DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            && ME_Taskbar_IsSafeTaskWindow(hwnd)) ? true : false
    } catch error {
        return false
    }
}

ME_Taskbar_OnMiddleClick() {
    global ME_Config, ME_State
    state := ME_State.Taskbar
    candidate := state.MiddleClickCandidate
    state.MiddleClickCandidate := false
    try {
        ; criterionでTaskButtonと識別済みの入力は、以後の失敗時もreplayしない。
        if (!ME_Taskbar_IsMiddleClickCandidateValid(candidate))
            return
        result := ME_Taskbar_ProbeResolveTaskButtonWindow(candidate.TaskAppId)
        if (IsObject(result) && result.Resolution == "AMBIGUOUS"
            && result.MatchCount > 1) {
            multiWindowMode := ME_Config.Taskbar.TaskButtonMiddleClickMultiWindow
            if (multiWindowMode = 0)
                return
            states := ME_Taskbar_GetMiddleClickCandidateStates(result)
            if (!IsObject(states))
                return
            if (multiWindowMode = 1) {
                targetState := ME_Taskbar_SelectMiddleClickMultiWindowTarget(states)
                if (!IsObject(targetState)
                    || !ME_Taskbar_IsMiddleClickWindowStateCurrent(targetState))
                    return
                hwnd := targetState.Hwnd
                if (!DllCall("User32\PostMessageW", "Ptr", hwnd, "UInt", 0x0112
                    , "Ptr", 0xF060, "Ptr", 0, "Int")) ; WM_SYSCOMMAND / SC_CLOSE
                    return
                return
            }
            if (multiWindowMode = 2) {
                ; 全件validation済みの固定snapshotをZ-order順に処理する。
                for _, candidateState in states {
                    if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
                        break
                    if (!ME_Taskbar_IsMiddleClickWindowStateCurrent(candidateState)) {
                        if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
                            break
                        continue
                    }
                    if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick"))
                        break
                    hwnd := candidateState.Hwnd
                    ; 各exact HWNDへ通常Closeを1回だけ送り、失敗時もretryしない。
                    DllCall("User32\PostMessageW", "Ptr", hwnd, "UInt", 0x0112
                        , "Ptr", 0xF060, "Ptr", 0, "Int") ; WM_SYSCOMMAND / SC_CLOSE
                }
                return
            }
            return
        }
        if (!IsObject(result) || !(result.Resolution == "RESOLVED")
            || result.MatchCount != 1 || !result.ResolvedHwnd)
            return
        hwnd := result.ResolvedHwnd
        ; resolverが選んだsame HWNDだけを再確認し、別候補へfallbackしない。
        if (!ME_Taskbar_CanOperate("TaskButtonMiddleClick")
            || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            || !ME_Taskbar_IsSafeTaskWindow(hwnd))
            return
        ; 通常Close要求だけを非同期送信する。失敗時のretryや強制終了は行わない。
        if (!DllCall("User32\PostMessageW", "Ptr", hwnd, "UInt", 0x0112
            , "Ptr", 0xF060, "Ptr", 0, "Int")) ; WM_SYSCOMMAND / SC_CLOSE
            return
    } catch error {
        return
    }
}

ME_Taskbar_ParseTaskAppId(automationId) {
    if (IsObject(automationId) || !RegExMatch(automationId, "^Appid:\s*(\S(?:.*\S)?)$", match))
        return ""
    return Trim(match1)
}

ME_Taskbar_AreAppIdsEqual(firstAppId, secondAppId) {
    if (IsObject(firstAppId) || IsObject(secondAppId)
        || StrLen(firstAppId) = 0 || StrLen(secondAppId) = 0
        || StrLen(firstAppId) != StrLen(secondAppId))
        return false
    try {
        ; 数字だけのAppIDも数値化せず、case-sensitiveな文字列として比較する。
        return (DllCall("Kernel32\lstrcmpW", "WStr", firstAppId, "WStr", secondAppId, "Int") = 0)
    } catch error {
        return false
    }
}

ME_Taskbar_IsSafeTaskWindow(hwnd) {
    try {
        if (!ME_AlwaysOnTop_IsSafeTopLevelWindow(hwnd)
            || !ME_AlwaysOnTop_GetWindowStyle(hwnd, -16, style)
            || (style & 0x48000000) ; WS_CHILD | WS_DISABLED
            || !ME_AlwaysOnTop_GetWindowStyle(hwnd, -20, exStyle))
            return false
        if (!(exStyle & 0x40000)) { ; WS_EX_APPWINDOWのみtool/owner除外の例外
            if ((exStyle & 0x80) ; WS_EX_TOOLWINDOW
                || DllCall("User32\GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")) ; GW_OWNER
                return false
        }
        WinGetTitle, title, ahk_id %hwnd%
        return (StrLen(Trim(title)) > 0)
    } catch error {
        return false
    }
}

ME_Taskbar_GetProcessFullImagePath(hwnd) {
    processHandle := 0
    try {
        if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
            return ""
        processId := 0
        if (!DllCall("User32\GetWindowThreadProcessId", "Ptr", hwnd, "UIntP", processId, "UInt")
            || !processId)
            return ""
        processHandle := DllCall("Kernel32\OpenProcess", "UInt", 0x1000
            , "Int", false, "UInt", processId, "Ptr") ; PROCESS_QUERY_LIMITED_INFORMATION
        if (!processHandle)
            return ""
        capacity := 32768
        length := capacity
        if (VarSetCapacity(buffer, capacity * 2, 0) < capacity * 2)
            return ""
        if (!DllCall("Kernel32\QueryFullProcessImageNameW", "Ptr", processHandle, "UInt", 0
            , "Ptr", &buffer, "UIntP", length, "Int") || length < 1 || length >= capacity)
            return ""
        return StrGet(&buffer, length, "UTF-16")
    } catch error {
        return ""
    } finally {
        if (processHandle) {
            closingHandle := processHandle
            processHandle := 0
            DllCall("Kernel32\CloseHandle", "Ptr", closingHandle, "Int")
        }
    }
}

ME_Taskbar_ProbeResolveTaskButtonWindow(taskAppId) {
    global ME_State
    if (IsObject(taskAppId) || StrLen(taskAppId) = 0)
        return false
    native := ME_State.Native
    nativeAvailable := (native.Initialized && native.Available && native.Module && !ME_State.CleanupStarted)
    result := {MatchCount: 0, Resolution: "UNRESOLVED", ResolvedHwnd: 0, Matches: []
        , CandidateHwnds: [], NativeAvailable: nativeAvailable, ResolutionSource: "NONE"}
    if (!nativeAvailable) {
        result.Resolution := "NATIVE_UNAVAILABLE"
        return result
    }
    try {
        WinGet, windowList, List
        Loop, % windowList {
            hwnd := windowList%A_Index%
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className))
                continue
            WinGetTitle, title, ahk_id %hwnd%
            effectiveAppId := ME_Native_GetEffectiveWindowAppUserModelId(hwnd)
            processPath := ME_Taskbar_GetProcessFullImagePath(hwnd)
            processName := ""
            SplitPath, processPath, processName
            WinGet, minMax, MinMax, ahk_id %hwnd%
            ; 読取中に閉じられた/再利用されたHWNDは一致候補にしない。
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId, currentThreadId, currentClass)
                || currentProcessId != processId || currentThreadId != threadId
                || !(currentClass == className) || StrLen(Trim(title)) = 0)
                continue
            if (!ME_Taskbar_AreAppIdsEqual(taskAppId, effectiveAppId))
                continue
            result.MatchCount += 1
            result.CandidateHwnds.Push(hwnd) ; 操作用は全件をWinGet ListのZ-order順で保持。
            ; 全件を数えるが、表示用scalarレコードは一致候補の先頭10件に限定する。
            if (result.MatchCount <= 10)
                result.Matches.Push({Hwnd: hwnd, Title: title, ProcessName: processName
                    , EffectiveWindowAppUserModelId: effectiveAppId, ProcessPath: processPath, MinMax: minMax})
        }
        if (result.MatchCount = 1) {
            result.Resolution := "RESOLVED"
            result.ResolutionSource := "NATIVE_APPID"
            result.ResolvedHwnd := result.CandidateHwnds[1]
            return result
        } else if (result.MatchCount > 1) {
            result.Resolution := "AMBIGUOUS"
            result.ResolutionSource := "NATIVE_APPID"
            return result
        }

        ; Native AppIDが正常に0件で、TaskButton AppID自体が厳密な絶対exe pathの場合だけ試す。
        exePathPattern := "i)^[a-z]:\\(?:[^\\/:*?""<>|]+\\)*[^\\/:*?""<>|]+\.exe$"
        if (result.MatchCount = 0 && RegExMatch(taskAppId, exePathPattern)) {
            WinGet, pathWindowList, List
            Loop, % pathWindowList {
                hwnd := pathWindowList%A_Index%
                if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                    || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className))
                    continue
                WinGetTitle, title, ahk_id %hwnd%
                processPath := ME_Taskbar_GetProcessFullImagePath(hwnd)
                processName := ""
                SplitPath, processPath, processName
                WinGet, minMax, MinMax, ahk_id %hwnd%
                ; 通常resolverと同じidentity再確認を通ったwindowだけを比較対象にする。
                if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                    || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId, currentThreadId, currentClass)
                    || currentProcessId != processId || currentThreadId != threadId
                    || !(currentClass == className) || StrLen(Trim(title)) = 0
                    || StrLen(processPath) = 0)
                    continue
                if (DllCall("Kernel32\CompareStringOrdinal", "WStr", taskAppId, "Int", -1
                    , "WStr", processPath, "Int", -1, "Int", 1, "Int") != 2)
                    continue
                result.MatchCount += 1
                result.CandidateHwnds.Push(hwnd)
                if (result.MatchCount <= 10)
                    result.Matches.Push({Hwnd: hwnd, Title: title, ProcessName: processName
                        , EffectiveWindowAppUserModelId: "", ProcessPath: processPath, MinMax: minMax})
            }
            if (result.MatchCount = 1) {
                result.Resolution := "RESOLVED"
                result.ResolutionSource := "EXE_PATH_FALLBACK"
                result.ResolvedHwnd := result.CandidateHwnds[1]
                return result
            } else if (result.MatchCount > 1) {
                result.Resolution := "AMBIGUOUS"
                result.ResolutionSource := "EXE_PATH_FALLBACK"
                return result
            }
        }
        if (result.MatchCount = 0
            && ME_Taskbar_AreAppIdsEqual(taskAppId, "Microsoft.Windows.Explorer")) {
            return ME_Taskbar_ProbeResolveExplorerWindow()
        }
        return ME_Taskbar_ProbeResolveKnownFolderPath(taskAppId)
    } catch error {
        return false ; 列挙途中の失敗を一意解決として扱わない。
    }
}

ME_Taskbar_GetKnownFolderExecutablePath(taskAppId) {
    knownFolderPathPtr := 0
    try {
        ; v1.0.0ではcanonicalな{GUID}\relative\path.exe形式だけを受理する。
        knownFolderPattern := "^(\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\})\\(.+)$"
        if (IsObject(taskAppId) || !RegExMatch(taskAppId, knownFolderPattern, match))
            return ""
        knownFolderIdText := match1
        suffix := match2

        ; root/drive/UNC/device形式、空segment、dot segment、Win32で曖昧な末尾を拒否する。
        relativeExePathPattern := "i)^(?:[^\\/:*?""<>|\x00-\x1F]+\\)*[^\\/:*?""<>|\x00-\x1F]+\.exe$"
        if (!RegExMatch(suffix, relativeExePathPattern)
            || RegExMatch(suffix, "(^|\\)\.{1,2}(\\|$)")
            || RegExMatch(suffix, "(^|\\)\s")
            || RegExMatch(suffix, "\s(\\|$)")
            || RegExMatch(suffix, "(^|\\)[^\\]*\.(\\|$)")
            || RegExMatch(suffix, "i)(^|\\)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.[^\\]*)?(\\|$)"))
            return ""

        ; 文字列表現ではなく、parse済みGUID同士で許可対象を限定する。
        VarSetCapacity(appIdGuid, 16, 0)
        VarSetCapacity(programFilesX86Guid, 16, 0)
        if (DllCall("Ole32\CLSIDFromString", "WStr", knownFolderIdText
                , "Ptr", &appIdGuid, "Int") < 0
            || DllCall("Ole32\CLSIDFromString", "WStr"
                , "{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}"
                , "Ptr", &programFilesX86Guid, "Int") < 0)
            return ""
        Loop, 4 {
            offset := (A_Index - 1) * 4
            if (NumGet(appIdGuid, offset, "UInt")
                != NumGet(programFilesX86Guid, offset, "UInt"))
                return ""
        }

        hresult := DllCall("Shell32\SHGetKnownFolderPath", "Ptr", &programFilesX86Guid
            , "UInt", 0, "Ptr", 0, "PtrP", knownFolderPathPtr, "Int")
        if (hresult < 0 || !knownFolderPathPtr)
            return ""
        knownFolderRoot := StrGet(knownFolderPathPtr, "UTF-16")
        if (StrLen(knownFolderRoot) = 0)
            return ""
        fullPath := knownFolderRoot . "\" . suffix
        absoluteExePathPattern := "i)^[a-z]:\\(?:[^\\/:*?""<>|]+\\)*[^\\/:*?""<>|]+\.exe$"
        if (!RegExMatch(fullPath, absoluteExePathPattern))
            return ""
        return fullPath
    } catch error {
        return ""
    } finally {
        ; SHGetKnownFolderPathの返却bufferは成功後の途中returnでも必ず解放する。
        if (knownFolderPathPtr)
            DllCall("Ole32\CoTaskMemFree", "Ptr", knownFolderPathPtr)
    }
}

ME_Taskbar_ProbeResolveKnownFolderPath(taskAppId) {
    result := {MatchCount: 0, Resolution: "UNRESOLVED", ResolvedHwnd: 0, Matches: []
        , CandidateHwnds: [], NativeAvailable: true, ResolutionSource: "NONE"}
    expectedProcessPath := ME_Taskbar_GetKnownFolderExecutablePath(taskAppId)
    if (StrLen(expectedProcessPath) = 0)
        return result
    try {
        WinGet, windowList, List
        Loop, % windowList {
            hwnd := windowList%A_Index%
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className))
                continue
            WinGetTitle, title, ahk_id %hwnd%
            processPath := ME_Taskbar_GetProcessFullImagePath(hwnd)
            processName := ""
            SplitPath, processPath, processName
            WinGet, minMax, MinMax, ahk_id %hwnd%
            ; A2と同じidentity再確認を通ったwindowだけを比較対象にする。
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId, currentThreadId, currentClass)
                || currentProcessId != processId || currentThreadId != threadId
                || !(currentClass == className) || StrLen(Trim(title)) = 0
                || StrLen(processPath) = 0)
                continue
            if (DllCall("Kernel32\CompareStringOrdinal", "WStr", expectedProcessPath, "Int", -1
                , "WStr", processPath, "Int", -1, "Int", 1, "Int") != 2)
                continue
            result.MatchCount += 1
            result.CandidateHwnds.Push(hwnd)
            if (result.MatchCount <= 10)
                result.Matches.Push({Hwnd: hwnd, Title: title, ProcessName: processName
                    , EffectiveWindowAppUserModelId: "", ProcessPath: processPath, MinMax: minMax})
        }
        if (result.MatchCount = 1) {
            result.Resolution := "RESOLVED"
            result.ResolutionSource := "KNOWN_FOLDER_PATH_FALLBACK"
            result.ResolvedHwnd := result.CandidateHwnds[1]
        } else if (result.MatchCount > 1) {
            result.Resolution := "AMBIGUOUS"
            result.ResolutionSource := "KNOWN_FOLDER_PATH_FALLBACK"
        }
        return result
    } catch error {
        return false ; 不完全な列挙結果を一意解決として扱わない。
    }
}

ME_Taskbar_ProbeResolveExplorerWindow() {
    ; Native照合が正常に完了し、Explorerの完全一致AppIDで0件のときだけ呼ぶ。
    result := {MatchCount: 0, Resolution: "UNRESOLVED", ResolvedHwnd: 0, Matches: []
        , CandidateHwnds: [], NativeAvailable: true, ResolutionSource: "EXPLORER_FALLBACK"}
    try {
        WinGet, windowList, List
        Loop, % windowList {
            hwnd := windowList%A_Index%
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd))
                continue
            WinGet, processName, ProcessName, ahk_id %hwnd%
            if (!(processName = "explorer.exe")
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, processId, threadId, className)
                || !(className == "CabinetWClass"))
                continue
            WinGetTitle, title, ahk_id %hwnd%
            effectiveAppId := ME_Native_GetEffectiveWindowAppUserModelId(hwnd) ; 表示専用。空を一致扱いしない。
            processPath := ME_Taskbar_GetProcessFullImagePath(hwnd)
            WinGet, minMax, MinMax, ahk_id %hwnd%
            ; 読取中に閉じられた/再利用されたHWNDは候補にしない。
            if (!ME_Taskbar_IsSafeTaskWindow(hwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(hwnd, currentProcessId, currentThreadId, currentClass)
                || currentProcessId != processId || currentThreadId != threadId
                || !(currentClass == "CabinetWClass"))
                continue
            result.MatchCount += 1
            result.CandidateHwnds.Push(hwnd) ; 通常resolverと同じ全件・列挙順の契約。
            if (result.MatchCount <= 10)
                result.Matches.Push({Hwnd: hwnd, Title: title, ProcessName: processName
                    , EffectiveWindowAppUserModelId: effectiveAppId, ProcessPath: processPath, MinMax: minMax})
        }
        if (result.MatchCount = 1) {
            result.Resolution := "RESOLVED"
            result.ResolvedHwnd := result.CandidateHwnds[1]
        } else if (result.MatchCount > 1) {
            result.Resolution := "AMBIGUOUS"
        }
        return result
    } catch error {
        return false ; 不完全な列挙結果を一意解決として扱わない。
    }
}

ME_Taskbar_PrepareTarget() {
    global ME_State
    state := ME_State.Taskbar
    state.Candidate := false
    try {
        if (!ME_Taskbar_CanOperate("Any") || !ME_GetCursorScreenPoint(screenX, screenY))
            return false
        if (!ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass))
            return false
        if (ME_Taskbar_IsStartAtPoint(screenX, screenY, rootHwnd, rootClass)) {
            if (!ME_Taskbar_CanOperate())
                return false
            ; Candidateにはscalarのみを保存し、UIA elementの所有権を持たせない。
            state.Candidate := {Kind: "Start", TaskbarHwnd: rootHwnd, TaskbarClass: rootClass
                , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount}
            return true
        }
        if (!ME_Taskbar_CanOperate("TaskButtonProbe"))
            return false
        candidate := ME_Taskbar_GetTaskButtonIdentityAtPoint(screenX, screenY)
        if (!IsObject(candidate) || !ME_Taskbar_CanOperate("TaskButtonProbe"))
            return false
        state.Candidate := candidate
        return true
    } catch error {
        state.Candidate := false
        return false
    }
}

ME_Taskbar_IsCandidateValid(candidate) {
    global ME_State
    if (IsObject(candidate) && candidate.Kind == "TaskButtonProbe")
        return ME_Taskbar_IsTaskButtonProbeCandidateValid(candidate)
    try {
        if (!IsObject(candidate) || !(candidate.Kind == "Start")
            || !candidate.HasKey("Tick") || !candidate.TaskbarHwnd
            || !ME_Taskbar_CanOperate())
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.Taskbar.CandidateLifetimeMs
            || !DllCall("User32\IsWindow", "Ptr", candidate.TaskbarHwnd, "Int"))
            return false
        ; capture座標との一致は要求せず、現在位置でStartを再判定する。
        if (!ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_Taskbar_GetRootAtPoint(screenX, screenY, rootHwnd, rootClass)
            || rootHwnd != candidate.TaskbarHwnd || !(rootClass == candidate.TaskbarClass))
            return false
        if (!ME_Taskbar_IsStartAtPoint(screenX, screenY, rootHwnd, rootClass)
            || rootHwnd != candidate.TaskbarHwnd || !(rootClass == candidate.TaskbarClass)
            || !ME_Taskbar_CanOperate())
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        return (elapsed <= ME_State.Taskbar.CandidateLifetimeMs) ? true : false
    } catch error {
        return false
    }
}

ME_Taskbar_IsWindowHandleValue(value) {
    if (IsObject(value))
        return false
    text := Trim(value)
    if (RegExMatch(text, "^[0-9]+$"))
        return RegExMatch(text, "[1-9]") ? true : false
    if (RegExMatch(text, "i)^0x[0-9a-f]+$"))
        return RegExMatch(text, "i)[1-9a-f]") ? true : false
    return false
}

ME_Taskbar_GetTaskButtonCandidateStates(result) {
    if (!IsObject(result) || !result.NativeAvailable
        || !result.HasKey("CandidateHwnds") || !IsObject(result.CandidateHwnds)
        || IsObject(result.MatchCount) || !ME_IsIntegerString(result.MatchCount)
        || result.MatchCount <= 1 || !(result.Resolution == "AMBIGUOUS")
        || result.CandidateHwnds.MaxIndex() != result.MatchCount)
        return false

    states := []
    seen := {}
    expectedIndex := 0
    for index, hwnd in result.CandidateHwnds {
        expectedIndex += 1
        ; 欠落・余分なキー・重複も候補集合の不整合として全体を拒否する。
        if (index != expectedIndex || !ME_Taskbar_IsWindowHandleValue(hwnd)
            || seen.HasKey(hwnd)
            || !ME_Taskbar_CanOperate("TaskButtonProbe")
            || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            || !ME_Taskbar_IsSafeTaskWindow(hwnd))
            return false
        WinGet, minMax, MinMax, ahk_id %hwnd%
        if (StrLen(minMax) = 0 || !(minMax = -1 || minMax = 0 || minMax = 1))
            return false
        seen[hwnd] := true
        states.Push({Hwnd: hwnd, MinMax: minMax})
    }
    if (expectedIndex != result.MatchCount)
        return false
    return states ; このWheel入力だけで使用し、global stateには保存しない。
}

ME_Taskbar_SelectMultiWindowTarget(states, direction, taskAppId) {
    if (!IsObject(states) || states.MaxIndex() < 2
        || !(direction == "Up" || direction == "Down")
        || IsObject(taskAppId) || StrLen(taskAppId) = 0)
        return 0
    if (direction == "Up") {
        for _, candidate in states {
            if (candidate.MinMax = -1)
                return {Hwnd: candidate.Hwnd, MinMax: -1}
        }
    }
    ; 全候補のfresh state取得後、foregroundがgroup内か明確な別groupかを確定する。
    foregroundHwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd)
        return 0
    activeInGroup := false
    activeMinMax := -1
    firstVisible := 0
    for _, candidate in states {
        if (candidate.Hwnd = foregroundHwnd) {
            activeInGroup := true
            activeMinMax := candidate.MinMax
        }
        if (candidate.MinMax != -1) {
            if (!firstVisible)
                firstVisible := candidate.Hwnd
        }
    }
    if (!activeInGroup) {
        if (!DllCall("User32\IsWindow", "Ptr", foregroundHwnd, "Int")
            || !ME_Taskbar_IsSafeTaskWindow(foregroundHwnd))
            return 0
        foregroundAppId := ME_Native_GetEffectiveWindowAppUserModelId(foregroundHwnd)
        if (StrLen(foregroundAppId) > 0) {
            if (ME_Taskbar_AreAppIdsEqual(foregroundAppId, taskAppId))
                return 0
        } else {
            ; AppID取得不能時だけ、既存Explorer fallbackと同じidentity条件を限定再利用する。
            WinGet, foregroundProcessName, ProcessName, ahk_id %foregroundHwnd%
            if (!(foregroundProcessName = "explorer.exe")
                || !ME_AlwaysOnTop_GetWindowIdentity(foregroundHwnd, foregroundProcessId
                    , foregroundThreadId, foregroundClassName)
                || !(foregroundClassName == "CabinetWClass")
                || !ME_Taskbar_IsSafeTaskWindow(foregroundHwnd)
                || !ME_AlwaysOnTop_GetWindowIdentity(foregroundHwnd, currentProcessId
                    , currentThreadId, currentClassName)
                || currentProcessId != foregroundProcessId
                || currentThreadId != foregroundThreadId
                || !(currentClassName == "CabinetWClass")
                || ME_Taskbar_AreAppIdsEqual(taskAppId, "Microsoft.Windows.Explorer"))
                return 0
        }
    }
    if (direction == "Down") {
        if (activeInGroup)
            hwnd := (activeMinMax = -1) ? 0 : foregroundHwnd
        else
            hwnd := firstVisible
        return hwnd ? {Hwnd: hwnd, MinMax: (activeInGroup ? activeMinMax : 0)} : 0
    }
    if (activeInGroup)
        return 0 ; 全window visibleかつgroup内activeではcycleしない。
    return firstVisible ? {Hwnd: firstVisible, MinMax: 0} : 0
}

ME_Taskbar_GetMinimizeStackGroupKey(taskAppId) {
    if (IsObject(taskAppId) || StrLen(taskAppId) = 0)
        return ""
    return "TaskAppId:" . StrLen(taskAppId) . ":" . taskAppId
}

ME_Taskbar_PushMinimizedWindow(taskAppId, hwnd) {
    global ME_State
    groupKey := ME_Taskbar_GetMinimizeStackGroupKey(taskAppId)
    if (groupKey = "" || !ME_Taskbar_IsWindowHandleValue(hwnd))
        return false
    previousCritical := A_IsCritical
    Critical, On
    try {
        if (ME_State.CleanupStarted || ME_State.Taskbar.CleanupStarted)
            return false
        stacks := ME_State.Taskbar.MinimizeStacks
        if (!IsObject(stacks))
            return false
        if (stacks.HasKey(groupKey)) {
            stack := stacks[groupKey]
            if (!IsObject(stack))
                return false
        } else {
            stack := []
            stacks[groupKey] := stack
        }
        existingIndex := 0
        expectedIndex := 0
        for index, entry in stack {
            expectedIndex += 1
            if (index != expectedIndex || !IsObject(entry) || !(entry.GroupKey == groupKey)
                || !ME_Taskbar_IsWindowHandleValue(entry.Hwnd))
                return false
            if (entry.Hwnd = hwnd) {
                if (existingIndex)
                    return false ; 同一HWNDの複数entryはcorruptionとして拒否する。
                existingIndex := index
            }
        }
        ; 全件validation後に古い位置から外し、今回のminimize順として末尾へ積み直す。
        if (existingIndex)
            stack.RemoveAt(existingIndex)
        stack.Push({Hwnd: hwnd, GroupKey: groupKey})
        return true
    } finally {
        Critical, % previousCritical
    }
}

ME_Taskbar_PeekMinimizedWindow(taskAppId) {
    global ME_State
    groupKey := ME_Taskbar_GetMinimizeStackGroupKey(taskAppId)
    if (groupKey = "")
        return false
    previousCritical := A_IsCritical
    Critical, On
    try {
        if (ME_State.CleanupStarted || ME_State.Taskbar.CleanupStarted)
            return false
        stacks := ME_State.Taskbar.MinimizeStacks
        if (!IsObject(stacks))
            return false
        if (!stacks.HasKey(groupKey))
            return {HasEntry: false, GroupKey: groupKey}
        stack := stacks[groupKey]
        if (!IsObject(stack))
            return false
        topIndex := stack.MaxIndex()
        if (!topIndex) {
            stacks.Delete(groupKey)
            return {HasEntry: false, GroupKey: groupKey}
        }
        entry := stack[topIndex]
        if (!IsObject(entry))
            return false
        return {HasEntry: true, GroupKey: groupKey, Hwnd: entry.Hwnd
            , EntryGroupKey: entry.GroupKey}
    } finally {
        Critical, % previousCritical
    }
}

ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, hwnd) {
    global ME_State
    groupKey := ME_Taskbar_GetMinimizeStackGroupKey(taskAppId)
    if (groupKey = "" || IsObject(hwnd))
        return false
    previousCritical := A_IsCritical
    Critical, On
    try {
        if (ME_State.CleanupStarted || ME_State.Taskbar.CleanupStarted)
            return false
        stacks := ME_State.Taskbar.MinimizeStacks
        if (!IsObject(stacks) || !stacks.HasKey(groupKey))
            return false
        stack := stacks[groupKey]
        if (!IsObject(stack) || !stack.MaxIndex())
            return false
        topIndex := stack.MaxIndex()
        entry := stack[topIndex]
        if (!IsObject(entry) || entry.Hwnd != hwnd)
            return false
        stack.RemoveAt(topIndex)
        if (!stack.MaxIndex())
            stacks.Delete(groupKey)
        return true
    } finally {
        Critical, % previousCritical
    }
}

ME_Taskbar_ApplyTaskButtonWheel(result, direction, taskAppId := "") {
    global ME_Config
    if (!(direction == "Up" || direction == "Down"))
        return false
    try {
        ; 検証済みTaskButton入力は、解決不能・候補不整合でも他のWheel処理へ流さない。
        if (IsObject(result) && ME_Config.Taskbar.TaskButtonWheelMultiWindow = 1
            && result.MatchCount > 1) {
            states := ME_Taskbar_GetTaskButtonCandidateStates(result)
            if (!IsObject(states))
                return true
            stackTargetHwnd := 0
            if (direction == "Up") {
                stackTop := ME_Taskbar_PeekMinimizedWindow(taskAppId)
                if (!IsObject(stackTop))
                    return true
                if (stackTop.HasEntry) {
                    topHwnd := stackTop.Hwnd
                    validTop := (stackTop.EntryGroupKey == stackTop.GroupKey
                        && ME_Taskbar_IsWindowHandleValue(topHwnd))
                    topStateFound := false
                    if (validTop) {
                        for _, candidateState in states {
                            if (candidateState.Hwnd = topHwnd) {
                                topStateFound := true
                                validTop := (candidateState.MinMax = -1)
                                break
                            }
                        }
                    }
                    if (!topStateFound)
                        validTop := false
                    if (validTop) {
                        if (!ME_Taskbar_CanOperate("TaskButtonProbe")
                            || !DllCall("User32\IsWindow", "Ptr", topHwnd, "Int")
                            || !ME_Taskbar_IsSafeTaskWindow(topHwnd)) {
                            validTop := false
                        } else {
                            WinGet, topMinMax, MinMax, ahk_id %topHwnd%
                            if (topMinMax != -1)
                                validTop := false
                        }
                    }
                    if (!validTop) {
                        ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, topHwnd)
                        return true ; stale整理後、同じ入力では次entry/live Z-orderへ進まない。
                    }
                    stackTargetHwnd := topHwnd
                }
            }
            if (direction == "Up" && stackTargetHwnd) {
                target := {Hwnd: stackTargetHwnd, MinMax: -1, FromMinimizeStack: true}
            } else {
                target := ME_Taskbar_SelectMultiWindowTarget(states, direction, taskAppId)
            }
            if (!IsObject(target) || !target.Hwnd)
                return true
            hwnd := target.Hwnd
            ; 選択時のvisible/minimized区分が変化していれば、別候補を選ばずno-op。
            canOperate := ME_Taskbar_CanOperate("TaskButtonProbe")
            windowExists := DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            windowSafe := windowExists ? ME_Taskbar_IsSafeTaskWindow(hwnd) : false
            if (!canOperate || !windowExists || !windowSafe) {
                if (target.FromMinimizeStack && (!windowExists || !windowSafe))
                    ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, hwnd)
                return true
            }
            WinGet, minMax, MinMax, ahk_id %hwnd%
            if (StrLen(minMax) = 0 || !(minMax = -1 || minMax = 0 || minMax = 1)) {
                if (target.FromMinimizeStack)
                    ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, hwnd)
                return true
            }
            if (direction == "Down") {
                if (target.MinMax = -1 || minMax = -1)
                    return true
                WinMinimize, ahk_id %hwnd%
                ; 自身のDownで実際にminimizeできた同じHWNDだけをvolatile LIFOへ記録する。
                if (ME_Taskbar_CanOperate("TaskButtonProbe")
                    && DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
                    && ME_Taskbar_IsSafeTaskWindow(hwnd)) {
                    WinGet, minimizedMinMax, MinMax, ahk_id %hwnd%
                    if (minimizedMinMax = -1)
                        ME_Taskbar_PushMinimizedWindow(taskAppId, hwnd)
                }
                return true
            }
            if (target.MinMax = -1) {
                if (minMax != -1) {
                    if (target.FromMinimizeStack && (minMax = 0 || minMax = 1))
                        ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, hwnd)
                    return true
                }
                WinRestore, ahk_id %hwnd%
                if (!ME_Taskbar_CanOperate("TaskButtonProbe")
                    || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
                    || !ME_Taskbar_IsSafeTaskWindow(hwnd))
                    return true
                WinGet, restoredMinMax, MinMax, ahk_id %hwnd%
                if (!(restoredMinMax = 0 || restoredMinMax = 1))
                    return true
                if (target.FromMinimizeStack) {
                    try {
                        WinActivate, ahk_id %hwnd%
                    } finally {
                        ; restore成立後はactivate成否にかかわらずminimized履歴から除去する。
                        ME_Taskbar_RemoveTopMinimizedWindow(taskAppId, hwnd)
                    }
                } else {
                    WinActivate, ahk_id %hwnd%
                }
                return true
            }
            if (minMax = -1)
                return true
            WinActivate, ahk_id %hwnd%
            return true
        }
        ; MultiWindow=0、および=1でも1-windowなら従来のPASS済み経路を使う。
        if (!IsObject(result) || !(result.Resolution == "RESOLVED")
            || result.MatchCount != 1 || !result.ResolvedHwnd)
            return true
        hwnd := result.ResolvedHwnd
        ; 選択後は同じHWNDだけを再確認し、無効でも別候補へ切り替えない。
        if (!DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
            return true
        WinGet, minMax, MinMax, ahk_id %hwnd%
        if (StrLen(minMax) = 0 || !(minMax = -1 || minMax = 0 || minMax = 1))
            return true
        if (!ME_Taskbar_CanOperate("TaskButtonProbe")
            || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            || !ME_Taskbar_IsSafeTaskWindow(hwnd))
            return true
        if (direction == "Down") {
            if (minMax != -1)
                WinMinimize, ahk_id %hwnd%
            return true
        }
        if (minMax = -1)
            WinRestore, ahk_id %hwnd%
        ; 復元後も同じHWNDだけを再検証し、別windowへ選び直さない。
        if (ME_Taskbar_CanOperate("TaskButtonProbe")
            && DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
            && ME_Taskbar_IsSafeTaskWindow(hwnd))
            WinActivate, ahk_id %hwnd%
        return true
    } catch error {
        return true ; 操作失敗後も二重処理やnative Wheel replayを起こさない。
    }
}

ME_Taskbar_HandleWheel(input) {
    global ME_State
    state := ME_State.Taskbar
    try {
        if (!IsObject(input) || !ME_Taskbar_CanOperate("Any"))
            return false
        direction := input.Direction
        if (!(direction == "Up" || direction == "Down"))
            return false
        if (!IsObject(state.Candidate) && !ME_Taskbar_PrepareTarget())
            return false
        candidate := state.Candidate
        state.Candidate := false
        if (!ME_Taskbar_IsCandidateValid(candidate))
            return false
        if (candidate.Kind == "TaskButtonProbe") {
            result := ME_Taskbar_ProbeResolveTaskButtonWindow(candidate.TaskAppId)
            return ME_Taskbar_ApplyTaskButtonWheel(result, direction, candidate.TaskAppId)
        }
        ; 自分が送ったWin+Mと未送信のWin+Shift+Mを1対1で管理するpair token。
        ; Windowsの実際のdesktop/minimize状態を表すものではない。
        shortcutCallback := Func("ME_Taskbar_SendStartDesktopToggle")
        if (direction == "Down") {
            if (state.StartDesktopTogglePending)
                return true
            if (!ME_RunWithSyntheticInput(shortcutCallback, "Down"))
                return false
            state.StartDesktopTogglePending := true
            return true
        }
        if (!state.StartDesktopTogglePending)
            return true
        if (!ME_RunWithSyntheticInput(shortcutCallback, "Up"))
            return false
        state.StartDesktopTogglePending := false
        return true
    } catch error {
        state.Candidate := false
        return false ; 共通Wheel入口の既存replayへ戻す。
    }
}

ME_Taskbar_SendStartDesktopToggle(direction) {
    if (direction == "Down")
        SendInput, #m
    else if (direction == "Up")
        SendInput, #+m
    else
        return false
    return true
}

ME_Taskbar_Cleanup() {
    global ME_State
    state := ME_State.Taskbar
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    criterionCallback := state.MiddleClickCriterionCallback
    middleClickHotkey := state.MiddleClickHotkeyName
    if (IsObject(criterionCallback)) {
        Hotkey, If, % criterionCallback
        if (state.MiddleClickRegistered)
            Hotkey, % middleClickHotkey, Off, UseErrorLevel
        Hotkey, If
    } else {
        Hotkey, If
    }
    state.MiddleClickRegistered := false
    state.MiddleClickCriterionCallback := false
    state.MiddleClickCallback := false
    state.MiddleClickCandidate := false
    state.Candidate := false
    state.StartDesktopTogglePending := false
    state.MinimizeStacks := {}
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; TrayWheelVolume (Phase 3 basic)
; -----------------------------------------------------------------------------

ME_InitializeTrayWheelVolume() {
    global ME_Config, ME_State
    state := ME_State.TrayWheelVolume
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false
    if (state.Initialized)
        return true
    state.Initialized := true
    if (!ME_Config.EnableFunction.Taskbar || !ME_Config.Taskbar.TrayWheelVolume
        || ME_MouseGestureL_IsEditMode())
        return true
    if (!ME_InitializeWheelInput()) {
        state.Initialized := false
        return false
    }
    return true
}

ME_TrayWheelVolume_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.TrayWheelVolume
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.EnableFunction.Taskbar && ME_Config.Taskbar.TrayWheelVolume
        && ME_CanRouteMouseInput() && ME_State.SyntheticInputDepth = 0) ? true : false
}

ME_TrayWheelVolume_GetWindowClassName(hwnd, ByRef className) {
    className := ""
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    VarSetCapacity(classBuffer, 512, 0)
    classLength := DllCall("User32\GetClassNameW", "Ptr", hwnd
        , "Ptr", &classBuffer, "Int", 256, "Int")
    if (classLength <= 0)
        return false
    className := StrGet(&classBuffer, classLength, "UTF-16")
    return true
}

ME_TrayWheelVolume_GetPrimaryTrayHostAtPoint(screenX, screenY
    , ByRef trayNotifyHwnd) {
    trayNotifyHwnd := 0
    pointHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!pointHwnd || !DllCall("User32\IsWindow", "Ptr", pointHwnd, "Int"))
        return false
    rootHwnd := DllCall("User32\GetAncestor", "Ptr", pointHwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if (!rootHwnd || !ME_TrayWheelVolume_GetWindowClassName(rootHwnd, rootClass)
        || !(rootClass == "Shell_TrayWnd"))
        return false ; secondary taskbarと未知のnative rootは対象外。

    currentHwnd := pointHwnd
    while (currentHwnd) {
        if (!ME_TrayWheelVolume_GetWindowClassName(currentHwnd, currentClass))
            return false
        if (currentClass == "TrayNotifyWnd") {
            trayNotifyHwnd := currentHwnd
            return true
        }
        if (currentHwnd = rootHwnd)
            break
        parentHwnd := DllCall("User32\GetParent", "Ptr", currentHwnd, "Ptr")
        if (!parentHwnd || parentHwnd = currentHwnd)
            return false
        currentHwnd := parentHwnd
    }
    return false
}

ME_TrayWheelVolume_GetElementIdentity(elementPtr, ByRef controlType
    , ByRef automationId, ByRef frameworkId, ByRef className) {
    controlType := ""
    automationId := ""
    frameworkId := ""
    className := ""
    if (!elementPtr
        || !ME_UIA_GetProperty(elementPtr, 30003, controlType)
        || !ME_UIA_GetProperty(elementPtr, 30011, automationId)
        || !ME_UIA_GetProperty(elementPtr, 30024, frameworkId)
        || !ME_UIA_GetProperty(elementPtr, 30012, className)
        || IsObject(controlType) || IsObject(automationId)
        || IsObject(frameworkId) || IsObject(className))
        return false
    return true
}

ME_TrayWheelVolume_IsTrayAtPoint(screenX, screenY, ByRef trayNotifyHwnd
    , useCache := true) {
    trayNotifyHwnd := 0
    if (!ME_TrayWheelVolume_GetPrimaryTrayHostAtPoint(screenX, screenY
        , initialTrayNotifyHwnd))
        return false

    elementPtr := 0
    parentPtr := 0
    try {
        elementPtr := ME_UIA_ElementFromPoint(screenX, screenY, useCache)
        if (!elementPtr)
            return false

        if (!ME_TrayWheelVolume_GetElementIdentity(elementPtr, controlType
            , automationId, frameworkId, className))
            return false
        matched := false
        ; Pattern Aはdirect elementだけ。SystemTray prefixもcase-sensitiveに限定する。
        if (frameworkId == "XAML" && controlType = 50000
            && automationId == "SystemTrayIcon"
            && SubStr(className, 1, StrLen("SystemTray.")) == "SystemTray.") {
            matched := true
        ; Pattern Bはdirect elementでも受理する。
        } else if (frameworkId == "XAML" && controlType = 50000
            && automationId == "NotifyItemIcon"
            && className == "SystemTray.NormalButton") {
            matched := true
        }
        if (!matched) {
            ; Pattern Bだけをparent 1階層で再確認し、それ以上は上がらない。
            parentPtr := ME_UIA_GetParent(elementPtr)
            if (parentPtr
                && ME_TrayWheelVolume_GetElementIdentity(parentPtr, parentControlType
                    , parentAutomationId, parentFrameworkId, parentClassName)
                && parentFrameworkId == "XAML" && parentControlType = 50000
                && parentAutomationId == "NotifyItemIcon"
                && parentClassName == "SystemTray.NormalButton")
                matched := true
        }
        if (!matched)
            return false

        ; UIA読取中のcursor移動・native host差替わりもfail closedにする。
        if (!ME_GetCursorScreenPoint(currentX, currentY)
            || currentX != screenX || currentY != screenY
            || !ME_TrayWheelVolume_GetPrimaryTrayHostAtPoint(currentX, currentY
                , currentTrayNotifyHwnd)
            || currentTrayNotifyHwnd != initialTrayNotifyHwnd)
            return false
        trayNotifyHwnd := initialTrayNotifyHwnd
        return true
    } catch error {
        return false
    } finally {
        if (parentPtr) {
            releasedPtr := parentPtr
            parentPtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (elementPtr) {
            releasedPtr := elementPtr
            elementPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_TrayWheelVolume_PrepareTarget() {
    global ME_State
    state := ME_State.TrayWheelVolume
    state.Candidate := false
    try {
        if (!ME_TrayWheelVolume_CanOperate()
            || !ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_TrayWheelVolume_IsTrayAtPoint(screenX, screenY, trayNotifyHwnd))
            return false
        state.Candidate := {Kind: "TrayWheelVolume", TrayNotifyHwnd: trayNotifyHwnd
            , ScreenX: screenX, ScreenY: screenY, Tick: A_TickCount}
        return true
    } catch error {
        state.Candidate := false
        return false
    }
}

ME_TrayWheelVolume_IsCandidateValid(candidate) {
    global ME_State
    try {
        if (!IsObject(candidate) || !(candidate.Kind == "TrayWheelVolume")
            || !candidate.HasKey("Tick") || !candidate.TrayNotifyHwnd
            || !ME_TrayWheelVolume_CanOperate())
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.TrayWheelVolume.CandidateLifetimeMs
            || !DllCall("User32\IsWindow", "Ptr", candidate.TrayNotifyHwnd, "Int")
            || !ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_TrayWheelVolume_IsTrayAtPoint(screenX, screenY
                , currentTrayNotifyHwnd, false)
            || currentTrayNotifyHwnd != candidate.TrayNotifyHwnd)
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        return (elapsed <= ME_State.TrayWheelVolume.CandidateLifetimeMs
            && ME_TrayWheelVolume_CanOperate()) ? true : false
    } catch error {
        return false
    }
}

ME_TrayWheelVolume_GetAccelerationMultiplier(direction, currentTick) {
    global ME_Config, ME_State
    state := ME_State.TrayWheelVolume
    strength := ME_Config.Volume.AccelStrength
    if (!(direction == "Up" || direction == "Down")
        || IsObject(currentTick) || !ME_IsIntegerString(currentTick)
        || IsObject(strength) || !ME_IsIntegerString(strength)
        || strength < 1 || strength > 5)
        return 0
    if (!(state.AccelDirection == direction))
        return 1
    elapsed := currentTick - state.AccelLastTick
    if (elapsed < 0)
        elapsed += 0x100000000
    if (elapsed <= 35)
        return strength
    if (elapsed <= 110) {
        highMultiplier := strength - 1
        return (highMultiplier < 1) ? 1 : highMultiplier
    }
    return 1
}

ME_TrayWheelVolume_AdjustMasterVolume(direction, multiplier := 1
    , ByRef resultingScalar := "", ByRef resultingMute := "") {
    global ME_Config
    resultingScalar := ""
    resultingMute := ""
    enumeratorPtr := 0
    devicePtr := 0
    endpointVolumePtr := 0
    try {
        if (!(direction == "Up" || direction == "Down"))
            return false
        step := ME_Config.Volume.Step
        if (IsObject(step) || !ME_IsIntegerString(step) || step <= 0 || step > 100)
            return false
        if (IsObject(multiplier) || !ME_IsIntegerString(multiplier)
            || multiplier < 1 || multiplier > 5)
            return false

        VarSetCapacity(clsidMMDeviceEnumerator, 16, 0)
        VarSetCapacity(iidMMDeviceEnumerator, 16, 0)
        VarSetCapacity(iidAudioEndpointVolume, 16, 0)
        if (DllCall("Ole32\CLSIDFromString", "WStr"
                , "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
                , "Ptr", &clsidMMDeviceEnumerator, "Int") < 0
            || DllCall("Ole32\CLSIDFromString", "WStr"
                , "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
                , "Ptr", &iidMMDeviceEnumerator, "Int") < 0
            || DllCall("Ole32\CLSIDFromString", "WStr"
                , "{5CDF2C82-841E-4546-9722-0CF74078229A}"
                , "Ptr", &iidAudioEndpointVolume, "Int") < 0)
            return false

        hresult := DllCall("Ole32\CoCreateInstance", "Ptr", &clsidMMDeviceEnumerator
            , "Ptr", 0, "UInt", 1, "Ptr", &iidMMDeviceEnumerator
            , "PtrP", enumeratorPtr, "Int") ; CLSCTX_INPROC_SERVER
        if (hresult < 0 || !enumeratorPtr)
            return false
        getDefaultMethod := ME_ComMethod(enumeratorPtr, 4)
        if (!getDefaultMethod)
            return false
        hresult := DllCall(getDefaultMethod, "Ptr", enumeratorPtr
            , "Int", 0, "Int", 0, "PtrP", devicePtr, "Int") ; eRender / eConsole
        if (hresult < 0 || !devicePtr)
            return false

        activateMethod := ME_ComMethod(devicePtr, 3)
        if (!activateMethod)
            return false
        hresult := DllCall(activateMethod, "Ptr", devicePtr, "Ptr", &iidAudioEndpointVolume
            , "UInt", 1, "Ptr", 0, "PtrP", endpointVolumePtr, "Int")
        if (hresult < 0 || !endpointVolumePtr)
            return false

        getVolumeMethod := ME_ComMethod(endpointVolumePtr, 9)
        setVolumeMethod := ME_ComMethod(endpointVolumePtr, 7)
        if (!getVolumeMethod || !setVolumeMethod)
            return false
        currentScalar := 0.0
        hresult := DllCall(getVolumeMethod, "Ptr", endpointVolumePtr
            , "FloatP", currentScalar, "Int")
        if (hresult < 0 || !(currentScalar >= 0.0 && currentScalar <= 1.0))
            return false

        delta := (step * multiplier) / 100.0
        newScalar := (direction == "Up") ? currentScalar + delta : currentScalar - delta
        if (newScalar < 0.0)
            newScalar := 0.0
        else if (newScalar > 1.0)
            newScalar := 1.0
        hresult := DllCall(setVolumeMethod, "Ptr", endpointVolumePtr
            , "Float", newScalar, "Ptr", 0, "Int")
        if (hresult < 0)
            return false
        resultingScalar := newScalar
        try {
            if (ME_VolumeOverlay_CanOperate()) {
                getMuteMethod := ME_ComMethod(endpointVolumePtr, 15)
                currentMute := 0
                if (getMuteMethod) {
                    overlayHresult := DllCall(getMuteMethod, "Ptr", endpointVolumePtr
                        , "IntP", currentMute, "Int")
                    if (overlayHresult >= 0)
                        resultingMute := currentMute ? 1 : 0
                }
            }
        } catch overlayError {
            resultingMute := ""
        }
        return true
    } catch error {
        return false
    } finally {
        if (endpointVolumePtr) {
            releasedPtr := endpointVolumePtr
            endpointVolumePtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (devicePtr) {
            releasedPtr := devicePtr
            devicePtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (enumeratorPtr) {
            releasedPtr := enumeratorPtr
            enumeratorPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_TrayWheelVolume_HandleWheel(input) {
    global ME_State
    state := ME_State.TrayWheelVolume
    ownsInput := IsObject(state.Candidate)
    try {
        if (!IsObject(input) || !ME_TrayWheelVolume_CanOperate())
            return ownsInput ? true : false
        direction := input.Direction
        if (!(direction == "Up" || direction == "Down"))
            return ownsInput ? true : false
        if (!ownsInput) {
            if (!ME_TrayWheelVolume_PrepareTarget())
                return false
            ownsInput := true
        }
        candidate := state.Candidate
        state.Candidate := false
        if (!ME_TrayWheelVolume_IsCandidateValid(candidate))
            return true
        currentTick := A_TickCount
        multiplier := ME_TrayWheelVolume_GetAccelerationMultiplier(direction, currentTick)
        if (!multiplier)
            return true
        ; 厳密にcapture済みならCore Audio失敗時も別機能やnative Wheelへfallbackしない。
        if (ME_TrayWheelVolume_AdjustMasterVolume(direction, multiplier
            , resultingScalar, resultingMute)) {
            state.AccelLastTick := currentTick
            state.AccelDirection := direction
            if (StrLen(resultingScalar) && StrLen(resultingMute))
                ME_VolumeOverlay_RequestShow(resultingScalar, resultingMute)
        }
        return true
    } catch error {
        state.Candidate := false
        return ownsInput ? true : false
    }
}

ME_TrayWheelVolume_Cleanup() {
    global ME_State
    state := ME_State.TrayWheelVolume
    state.CleanupStarted := true
    state.Candidate := false
    state.AccelLastTick := 0
    state.AccelDirection := ""
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; TrayMiddleClickMute (Phase 3)
; -----------------------------------------------------------------------------

ME_InitializeTrayMiddleClickMute() {
    global ME_Config, ME_State
    state := ME_State.TrayMiddleClickMute
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false
    if (state.Initialized)
        return true
    state.Initialized := true
    if (!ME_Config.EnableFunction.Taskbar || !ME_Config.Taskbar.TrayMiddleClickMute
        || ME_MouseGestureL_IsEditMode())
        return true

    state.CriterionCallback := Func("ME_TrayMiddleClickMute_ShouldCapture")
    state.MiddleClickCallback := Func("ME_TrayMiddleClickMute_OnMiddleClick")
    criterionCallback := state.CriterionCallback
    middleClickCallback := state.MiddleClickCallback
    middleClickHotkey := state.HotkeyName
    Hotkey, If, % criterionCallback
    Hotkey, % middleClickHotkey, % middleClickCallback, On UseErrorLevel
    registrationFailed := ErrorLevel ? true : false
    Hotkey, If
    if (registrationFailed) {
        state.CriterionCallback := false
        state.MiddleClickCallback := false
        state.Candidate := false
        return false
    }
    state.Registered := true
    return true
}

ME_TrayMiddleClickMute_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.TrayMiddleClickMute
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.EnableFunction.Taskbar && ME_Config.Taskbar.TrayMiddleClickMute
        && ME_CanRouteMouseInput() && ME_State.SyntheticInputDepth = 0) ? true : false
}

ME_TrayMiddleClickMute_ShouldCapture() {
    global ME_State
    state := ME_State.TrayMiddleClickMute
    state.Candidate := false
    try {
        if (!ME_TrayMiddleClickMute_CanOperate()
            || !ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_TrayWheelVolume_IsTrayAtPoint(screenX, screenY, trayNotifyHwnd)
            || !ME_TrayMiddleClickMute_CanOperate())
            return false
        state.Candidate := {Kind: "TrayMiddleClickMute"
            , TrayNotifyHwnd: trayNotifyHwnd, ScreenX: screenX, ScreenY: screenY
            , Tick: A_TickCount}
        return true
    } catch error {
        state.Candidate := false
        return false
    }
}

ME_TrayMiddleClickMute_IsCandidateValid(candidate) {
    global ME_State
    try {
        if (!IsObject(candidate) || !(candidate.Kind == "TrayMiddleClickMute")
            || !candidate.HasKey("Tick") || !candidate.HasKey("ScreenX")
            || !candidate.HasKey("ScreenY") || !candidate.TrayNotifyHwnd
            || !ME_TrayMiddleClickMute_CanOperate())
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        if (elapsed > ME_State.TrayMiddleClickMute.CandidateLifetimeMs
            || !DllCall("User32\IsWindow", "Ptr", candidate.TrayNotifyHwnd, "Int")
            || !ME_GetCursorScreenPoint(screenX, screenY)
            || !ME_TrayWheelVolume_IsTrayAtPoint(screenX, screenY
                , currentTrayNotifyHwnd, false)
            || currentTrayNotifyHwnd != candidate.TrayNotifyHwnd)
            return false
        elapsed := A_TickCount - candidate.Tick
        if (elapsed < 0)
            elapsed += 0x100000000
        return (elapsed <= ME_State.TrayMiddleClickMute.CandidateLifetimeMs
            && ME_TrayMiddleClickMute_CanOperate()) ? true : false
    } catch error {
        return false
    }
}

ME_TrayMiddleClickMute_ToggleMasterMute(ByRef resultingScalar := ""
    , ByRef resultingMute := "") {
    resultingScalar := ""
    resultingMute := ""
    enumeratorPtr := 0
    devicePtr := 0
    endpointVolumePtr := 0
    try {
        VarSetCapacity(clsidMMDeviceEnumerator, 16, 0)
        VarSetCapacity(iidMMDeviceEnumerator, 16, 0)
        VarSetCapacity(iidAudioEndpointVolume, 16, 0)
        if (DllCall("Ole32\CLSIDFromString", "WStr"
                , "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
                , "Ptr", &clsidMMDeviceEnumerator, "Int") < 0
            || DllCall("Ole32\CLSIDFromString", "WStr"
                , "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
                , "Ptr", &iidMMDeviceEnumerator, "Int") < 0
            || DllCall("Ole32\CLSIDFromString", "WStr"
                , "{5CDF2C82-841E-4546-9722-0CF74078229A}"
                , "Ptr", &iidAudioEndpointVolume, "Int") < 0)
            return false

        hresult := DllCall("Ole32\CoCreateInstance", "Ptr", &clsidMMDeviceEnumerator
            , "Ptr", 0, "UInt", 1, "Ptr", &iidMMDeviceEnumerator
            , "PtrP", enumeratorPtr, "Int") ; CLSCTX_INPROC_SERVER
        if (hresult < 0 || !enumeratorPtr)
            return false
        getDefaultMethod := ME_ComMethod(enumeratorPtr, 4)
        if (!getDefaultMethod)
            return false
        hresult := DllCall(getDefaultMethod, "Ptr", enumeratorPtr
            , "Int", 0, "Int", 0, "PtrP", devicePtr, "Int") ; eRender / eConsole
        if (hresult < 0 || !devicePtr)
            return false

        activateMethod := ME_ComMethod(devicePtr, 3)
        if (!activateMethod)
            return false
        hresult := DllCall(activateMethod, "Ptr", devicePtr, "Ptr", &iidAudioEndpointVolume
            , "UInt", 1, "Ptr", 0, "PtrP", endpointVolumePtr, "Int")
        if (hresult < 0 || !endpointVolumePtr)
            return false

        setMuteMethod := ME_ComMethod(endpointVolumePtr, 14)
        getMuteMethod := ME_ComMethod(endpointVolumePtr, 15)
        if (!setMuteMethod || !getMuteMethod)
            return false
        currentMute := 0
        hresult := DllCall(getMuteMethod, "Ptr", endpointVolumePtr
            , "IntP", currentMute, "Int")
        if (hresult < 0)
            return false
        newMute := currentMute ? 0 : 1
        hresult := DllCall(setMuteMethod, "Ptr", endpointVolumePtr
            , "Int", newMute, "Ptr", 0, "Int")
        if (hresult < 0)
            return false
        resultingMute := newMute
        try {
            if (ME_VolumeOverlay_CanOperate()) {
                getVolumeMethod := ME_ComMethod(endpointVolumePtr, 9)
                currentScalar := 0.0
                if (getVolumeMethod) {
                    overlayHresult := DllCall(getVolumeMethod, "Ptr", endpointVolumePtr
                        , "FloatP", currentScalar, "Int")
                    if (overlayHresult >= 0
                        && currentScalar >= 0.0 && currentScalar <= 1.0)
                        resultingScalar := currentScalar
                }
            }
        } catch overlayError {
            resultingScalar := ""
        }
        return true
    } catch error {
        return false
    } finally {
        if (endpointVolumePtr) {
            releasedPtr := endpointVolumePtr
            endpointVolumePtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (devicePtr) {
            releasedPtr := devicePtr
            devicePtr := 0
            ME_ComRelease(releasedPtr)
        }
        if (enumeratorPtr) {
            releasedPtr := enumeratorPtr
            enumeratorPtr := 0
            ME_ComRelease(releasedPtr)
        }
    }
}

ME_TrayMiddleClickMute_OnMiddleClick() {
    global ME_State
    state := ME_State.TrayMiddleClickMute
    candidate := state.Candidate
    state.Candidate := false
    try {
        ; criterionでstrict Trayと識別済みの入力は、以後の失敗時もreplayしない。
        if (!ME_TrayMiddleClickMute_IsCandidateValid(candidate))
            return
        if (ME_TrayMiddleClickMute_ToggleMasterMute(resultingScalar, resultingMute)
            && StrLen(resultingScalar) && StrLen(resultingMute))
            ME_VolumeOverlay_RequestShow(resultingScalar, resultingMute)
    } catch error {
        state.Candidate := false
        return
    }
}

ME_TrayMiddleClickMute_Cleanup() {
    global ME_State
    state := ME_State.TrayMiddleClickMute
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    criterionCallback := state.CriterionCallback
    middleClickHotkey := state.HotkeyName
    if (IsObject(criterionCallback)) {
        Hotkey, If, % criterionCallback
        if (state.Registered)
            Hotkey, % middleClickHotkey, Off, UseErrorLevel
        Hotkey, If
    } else {
        Hotkey, If
    }
    state.Registered := false
    state.CriterionCallback := false
    state.MiddleClickCallback := false
    state.Candidate := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; Volume Overlay (Phase 3)
; -----------------------------------------------------------------------------

ME_InitializeVolumeOverlay() {
    global ME_Config, ME_State
    state := ME_State.VolumeOverlay
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false
    if (state.Initialized)
        return true
    state.Initialized := true
    if (!ME_Config.VolumeOverlay.Enabled)
        return true

    processId := DllCall("Kernel32\GetCurrentProcessId", "UInt")
    state.BaseGuiName := "ME_VolumeBase_" . processId
    state.FillGuiName := "ME_VolumeFill_" . processId
    state.ValueGuiName := "ME_VolumeValue_" . processId
    state.UpdateTimerCallback := Func("ME_VolumeOverlay_OnUpdateTimer")
    state.HideTimerCallback := Func("ME_VolumeOverlay_OnHideTimer")
    ME_RegisterTimerForCleanup(state.UpdateTimerCallback)
    state.UpdateTimerRegistered := true
    ME_RegisterTimerForCleanup(state.HideTimerCallback)
    state.HideTimerRegistered := true
    return true
}

ME_VolumeOverlay_CanOperate() {
    global ME_Config, ME_State
    state := ME_State.VolumeOverlay
    return (state.Initialized && !state.CleanupStarted && !ME_State.CleanupStarted
        && ME_Config.VolumeOverlay.Enabled && state.UpdateTimerRegistered
        && state.HideTimerRegistered) ? true : false
}

ME_VolumeOverlay_DestroyGuis() {
    global ME_State
    state := ME_State.VolumeOverlay
    baseGuiName := state.BaseGuiName
    fillGuiName := state.FillGuiName
    valueGuiName := state.ValueGuiName
    if (baseGuiName != "")
        Gui, % baseGuiName ":Destroy"
    if (fillGuiName != "")
        Gui, % fillGuiName ":Destroy"
    if (valueGuiName != "")
        Gui, % valueGuiName ":Destroy"
    state.GuiCreated := false
    state.BaseHwnd := 0
    state.FillHwnd := 0
    state.ValueHwnd := 0
    state.NumberControlHwnd := 0
    state.MuteControlHwnd := 0
    state.Visible := false
}

ME_VolumeOverlay_CreateGuis() {
    global ME_Config, ME_State
    state := ME_State.VolumeOverlay
    if (state.GuiCreated)
        return true
    if (!ME_VolumeOverlay_CanOperate())
        return false

    baseGuiName := state.BaseGuiName
    fillGuiName := state.FillGuiName
    valueGuiName := state.ValueGuiName
    mainColor := ME_Config.VolumeOverlay.MainColor
    maskColor := (mainColor == "010101") ? "020202" : "010101"
    maskColorValue := (maskColor == "010101") ? 0x010101 : 0x020202

    baseHwnd := 0
    baseOptions := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
        . " +E0x08080020 +HwndbaseHwnd"
    Gui, %baseGuiName%:New, %baseOptions%
    state.BaseHwnd := baseHwnd
    if (!baseHwnd)
        return false
    Gui, %baseGuiName%:Color, 989898
    if (!DllCall("User32\SetLayeredWindowAttributes", "Ptr", baseHwnd
        , "UInt", 0, "UChar", 80, "UInt", 0x2, "Int")) {
        ME_VolumeOverlay_DestroyGuis()
        return false
    }

    fillHwnd := 0
    fillOptions := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
        . " +E0x08080020 +HwndfillHwnd"
    Gui, %fillGuiName%:New, %fillOptions%
    state.FillHwnd := fillHwnd
    if (!fillHwnd) {
        ME_VolumeOverlay_DestroyGuis()
        return false
    }
    Gui, %fillGuiName%:Color, %mainColor%
    if (!DllCall("User32\SetLayeredWindowAttributes", "Ptr", fillHwnd
        , "UInt", 0, "UChar", 200, "UInt", 0x2, "Int")) {
        ME_VolumeOverlay_DestroyGuis()
        return false
    }

    valueHwnd := 0
    valueOptions := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
        . " +E0x08080020 +HwndvalueHwnd"
    Gui, %valueGuiName%:New, %valueOptions%
    state.ValueHwnd := valueHwnd
    if (!valueHwnd) {
        ME_VolumeOverlay_DestroyGuis()
        return false
    }
    Gui, %valueGuiName%:Margin, 0, 0
    Gui, %valueGuiName%:Color, %maskColor%
    numberFontOptions := "s19 w600 q5 c" . mainColor
    Gui, %valueGuiName%:Font, %numberFontOptions%, メイリオ
    numberControlHwnd := 0
    numberOptions := "x0 y0 w48 h32 Right +0x200 HwndnumberControlHwnd"
    Gui, %valueGuiName%:Add, Text, %numberOptions%, 0
    muteFontOptions := "s22 w600 q5 c" . mainColor
    Gui, %valueGuiName%:Font, %muteFontOptions%, Segoe Fluent Icons
    muteControlHwnd := 0
    muteOptions := "x10 y-1 w48 h32 Center +0x200 Hidden HwndmuteControlHwnd"
    muteGlyph := Chr(0xE74F)
    Gui, %valueGuiName%:Add, Text, %muteOptions%, %muteGlyph%
    state.NumberControlHwnd := numberControlHwnd
    state.MuteControlHwnd := muteControlHwnd
    if (!numberControlHwnd || !muteControlHwnd
        || !DllCall("User32\SetLayeredWindowAttributes", "Ptr", valueHwnd
            , "UInt", maskColorValue, "UChar", 200, "UInt", 0x3, "Int")) {
        ME_VolumeOverlay_DestroyGuis()
        return false
    }
    state.GuiCreated := true
    return true
}

ME_VolumeOverlay_GetPlacement(ByRef barX, ByRef barY
    , ByRef numberX, ByRef numberY) {
    global ME_State
    barX := 0
    barY := 0
    numberX := 0
    numberY := 0
    if (!ME_GetCursorScreenPoint(screenX, screenY))
        return false

    VarSetCapacity(point, 8, 0)
    NumPut(screenX, point, 0, "Int")
    NumPut(screenY, point, 4, "Int")
    packedPoint := NumGet(point, 0, "Int64")
    monitorHwnd := DllCall("User32\MonitorFromPoint", "Int64", packedPoint
        , "UInt", 2, "Ptr") ; MONITOR_DEFAULTTONEAREST
    if (!monitorHwnd)
        return false
    VarSetCapacity(monitorInfo, 40, 0)
    NumPut(40, monitorInfo, 0, "UInt")
    if (!DllCall("User32\GetMonitorInfoW", "Ptr", monitorHwnd
        , "Ptr", &monitorInfo, "Int"))
        return false
    workLeft := NumGet(monitorInfo, 20, "Int")
    workTop := NumGet(monitorInfo, 24, "Int")
    workRight := NumGet(monitorInfo, 28, "Int")
    workBottom := NumGet(monitorInfo, 32, "Int")
    if (workRight <= workLeft || workBottom <= workTop)
        return false

    state := ME_State.VolumeOverlay
    barX := workRight - state.RightMargin - state.BarWidth
    barY := workBottom - state.BottomMargin - state.BarHeight
    if (barX < workLeft)
        barX := workLeft
    if (barY < workTop)
        barY := workTop
    numberX := barX - 4 - state.NumberWidth
    numberY := barY + Round((state.BarHeight - state.NumberHeight) / 2) + 2
    if (numberY < workTop)
        numberY := workTop
    return true
}

ME_VolumeOverlay_RenderPending() {
    global ME_State
    state := ME_State.VolumeOverlay
    pending := state.Pending
    if (!ME_VolumeOverlay_CanOperate() || !IsObject(pending)
        || !pending.HasKey("Scalar") || !pending.HasKey("Mute")
        || IsObject(pending.Scalar) || !StrLen(pending.Scalar)
        || !(pending.Scalar >= 0.0 && pending.Scalar <= 1.0)
        || IsObject(pending.Mute) || !ME_IsIntegerString(pending.Mute)
        || !(pending.Mute = 0 || pending.Mute = 1))
        return false
    if (!ME_VolumeOverlay_CreateGuis()
        || !ME_VolumeOverlay_GetPlacement(barX, barY, numberX, numberY))
        return false

    volumePercent := Round(pending.Scalar * 100)
    if (volumePercent < 0)
        volumePercent := 0
    else if (volumePercent > 100)
        volumePercent := 100
    fillWidth := Floor(state.BarWidth * volumePercent / 100)
    if (fillWidth < 0)
        fillWidth := 0
    else if (fillWidth > state.BarWidth)
        fillWidth := state.BarWidth
    if (!DllCall("User32\SetWindowTextW", "Ptr", state.NumberControlHwnd
        , "WStr", volumePercent, "Int"))
        return false
    if (pending.Mute) {
        DllCall("User32\ShowWindow", "Ptr", state.NumberControlHwnd, "Int", 0)
        DllCall("User32\ShowWindow", "Ptr", state.MuteControlHwnd, "Int", 8)
    } else {
        DllCall("User32\ShowWindow", "Ptr", state.MuteControlHwnd, "Int", 0)
        DllCall("User32\ShowWindow", "Ptr", state.NumberControlHwnd, "Int", 8)
    }

    baseShowOptions := "x" . barX . " y" . barY . " w" . state.BarWidth
        . " h" . state.BarHeight . " NA"
    Gui, % state.BaseGuiName ":Show", %baseShowOptions%
    if (fillWidth > 0) {
        fillShowOptions := "x" . barX . " y" . barY . " w" . fillWidth
            . " h" . state.BarHeight . " NA"
        Gui, % state.FillGuiName ":Show", %fillShowOptions%
    } else {
        Gui, % state.FillGuiName ":Hide"
    }
    valueShowOptions := "x" . numberX . " y" . numberY . " w" . state.NumberWidth
        . " h" . state.NumberHeight . " NA"
    Gui, % state.ValueGuiName ":Show", %valueShowOptions%
    state.Pending := false
    state.Visible := true
    return true
}

ME_VolumeOverlay_StartUpdateTimer() {
    global ME_State
    state := ME_State.VolumeOverlay
    if (state.UpdateTimerRunning)
        return true
    if (!ME_VolumeOverlay_CanOperate())
        return false
    updateTimerCallback := state.UpdateTimerCallback
    updateIntervalMs := state.UpdateIntervalMs
    SetTimer, % updateTimerCallback, % updateIntervalMs
    state.UpdateTimerRunning := true
    return true
}

ME_VolumeOverlay_StopUpdateTimer() {
    global ME_State
    state := ME_State.VolumeOverlay
    if (!state.UpdateTimerRunning)
        return
    if (IsObject(state.UpdateTimerCallback)) {
        updateTimerCallback := state.UpdateTimerCallback
        SetTimer, % updateTimerCallback, Off
    }
    state.UpdateTimerRunning := false
}

ME_VolumeOverlay_ResetHideTimer() {
    global ME_Config, ME_State
    state := ME_State.VolumeOverlay
    if (!ME_VolumeOverlay_CanOperate())
        return false
    durationMs := ME_Config.VolumeOverlay.DurationMs
    if (IsObject(durationMs) || !ME_IsIntegerString(durationMs)
        || durationMs < 250 || durationMs > 10000)
        return false
    hideTimerCallback := state.HideTimerCallback
    hideDelayMs := -1 * durationMs
    SetTimer, % hideTimerCallback, % hideDelayMs
    state.HideTimerRunning := true
    return true
}

ME_VolumeOverlay_RequestShow(masterScalar, isMuted) {
    global ME_State
    Critical, On
    state := ME_State.VolumeOverlay
    if (!ME_VolumeOverlay_CanOperate() || IsObject(masterScalar)
        || !StrLen(masterScalar) || !(masterScalar >= 0.0 && masterScalar <= 1.0)
        || IsObject(isMuted) || !ME_IsIntegerString(isMuted)
        || !(isMuted = 0 || isMuted = 1))
        return false
    state.Pending := {Scalar: masterScalar + 0.0, Mute: isMuted + 0}
    state.LastRequestTick := A_TickCount
    if (!state.UpdateTimerRunning) {
        if (!ME_VolumeOverlay_RenderPending()) {
            state.Pending := false
            return false
        }
        if (!ME_VolumeOverlay_StartUpdateTimer()) {
            ME_VolumeOverlay_Hide()
            return false
        }
    }
    if (!ME_VolumeOverlay_ResetHideTimer()) {
        state.Pending := false
        ME_VolumeOverlay_StopUpdateTimer()
        ME_VolumeOverlay_Hide()
        return false
    }
    return true
}

ME_VolumeOverlay_OnUpdateTimer() {
    global ME_State
    Critical, On
    state := ME_State.VolumeOverlay
    if (!ME_VolumeOverlay_CanOperate()) {
        state.Pending := false
        ME_VolumeOverlay_StopUpdateTimer()
        return
    }
    if (IsObject(state.Pending) && !ME_VolumeOverlay_RenderPending()) {
        state.Pending := false
        ME_VolumeOverlay_StopUpdateTimer()
        return
    }
    elapsed := A_TickCount - state.LastRequestTick
    if (elapsed < 0)
        elapsed += 0x100000000
    if (elapsed >= state.QuietMs)
        ME_VolumeOverlay_StopUpdateTimer()
}

ME_VolumeOverlay_Hide() {
    global ME_State
    state := ME_State.VolumeOverlay
    if (state.GuiCreated) {
        Gui, % state.BaseGuiName ":Hide"
        Gui, % state.FillGuiName ":Hide"
        Gui, % state.ValueGuiName ":Hide"
    }
    state.Visible := false
}

ME_VolumeOverlay_OnHideTimer() {
    global ME_State
    Critical, On
    state := ME_State.VolumeOverlay
    state.HideTimerRunning := false
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return
    ME_VolumeOverlay_Hide()
}

ME_VolumeOverlay_Cleanup() {
    global ME_State
    state := ME_State.VolumeOverlay
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true
    ; 共通Cleanupが登録timerをDelete済み。ここでは状態確定とGUI破棄だけを行う。
    state.UpdateTimerRunning := false
    state.HideTimerRunning := false
    state.Pending := false
    state.Visible := false
    ME_VolumeOverlay_DestroyGuis()
    state.UpdateTimerCallback := false
    state.UpdateTimerRegistered := false
    state.HideTimerCallback := false
    state.HideTimerRegistered := false
    state.LastRequestTick := 0
    state.BaseGuiName := ""
    state.FillGuiName := ""
    state.ValueGuiName := ""
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; 共通Wheel入力アダプタ
; -----------------------------------------------------------------------------

ME_InitializeWheelInput() {
    global ME_State
    state := ME_State.WheelInput
    if (state.Initialized)
        return true
    if (state.CleanupStarted)
        return false

    state.CriterionCallback := Func("ME_WheelInput_ShouldCapture")
    state.WheelUpCallback := Func("ME_WheelInput_OnWheelUp")
    state.WheelDownCallback := Func("ME_WheelInput_OnWheelDown")
    criterionCallback := state.CriterionCallback
    wheelUpCallback := state.WheelUpCallback
    wheelDownCallback := state.WheelDownCallback
    wheelUpHotkey := state.WheelUpHotkey
    wheelDownHotkey := state.WheelDownHotkey

    registrationFailed := false
    Hotkey, If, % criterionCallback
    Hotkey, % wheelUpHotkey, % wheelUpCallback, On UseErrorLevel
    if (ErrorLevel)
        registrationFailed := true
    else
        state.WheelUpRegistered := true
    if (!registrationFailed) {
        Hotkey, % wheelDownHotkey, % wheelDownCallback, On UseErrorLevel
        if (ErrorLevel)
            registrationFailed := true
        else
            state.WheelDownRegistered := true
    }
    Hotkey, If

    if (registrationFailed) {
        Hotkey, If, % criterionCallback
        if (state.WheelUpRegistered)
            Hotkey, % wheelUpHotkey, Off, UseErrorLevel
        if (state.WheelDownRegistered)
            Hotkey, % wheelDownHotkey, Off, UseErrorLevel
        Hotkey, If
        state.WheelUpRegistered := false
        state.WheelDownRegistered := false
        state.CriterionCallback := false
        state.WheelUpCallback := false
        state.WheelDownCallback := false
        return false
    }

    state.Initialized := true
    return true
}

ME_WheelInput_ShouldCapture() {
    global ME_State
    state := ME_State.WheelInput
    if (!state.Initialized || state.CleanupStarted
        || ME_State.CleanupStarted || ME_State.SyntheticInputDepth > 0) {
        ME_State.Taskbar.Candidate := false
        ME_State.TrayWheelVolume.Candidate := false
        ME_State.TabSwitch.Candidate := false
        ME_State.ExplorerViewMode.Candidate := false
        ME_State.SpecialScrollbarScroll.Candidate := false
        ME_State.BrowserDragScroll.Candidate := false
        return false
    }
    ME_State.Taskbar.Candidate := false
    ME_State.TrayWheelVolume.Candidate := false
    ME_State.TabSwitch.Candidate := false
    ME_State.ExplorerViewMode.Candidate := false
    ME_State.SpecialScrollbarScroll.Candidate := false
    ME_State.BrowserDragScroll.Candidate := false
    if (ME_Taskbar_PrepareTarget())
        return true
    if (ME_TrayWheelVolume_PrepareTarget())
        return true
    if (ME_TabSwitch_PrepareTarget())
        return true
    if (ME_ExplorerViewMode_PrepareTarget())
        return true
    if (ME_SpecialScrollbarScroll_PrepareTarget())
        return true
    if (ME_BrowserDragScroll_PrepareTarget())
        return true
    return false
}

ME_WheelInput_OnWheelUp() {
    global ME_State
    ME_AccelScroll_Reset()
    browserOwnsInput := IsObject(ME_State.BrowserDragScroll.Candidate)
    handled := false
    try {
        handled := ME_MouseGestureL_WheelEntry("Up", 1)
    } catch error {
        handled := false
    }
    if (browserOwnsInput) {
        ME_State.BrowserDragScroll.Candidate := false
        handled := true
    }
    if (!handled)
        ME_WheelInput_Replay("Up")
}

ME_WheelInput_OnWheelDown() {
    global ME_State
    ME_AccelScroll_Reset()
    browserOwnsInput := IsObject(ME_State.BrowserDragScroll.Candidate)
    handled := false
    try {
        handled := ME_MouseGestureL_WheelEntry("Down", 1)
    } catch error {
        handled := false
    }
    if (browserOwnsInput) {
        ME_State.BrowserDragScroll.Candidate := false
        handled := true
    }
    if (!handled)
        ME_WheelInput_Replay("Down")
}

ME_WheelInput_Replay(direction) {
    if (!(direction == "Up" || direction == "Down"))
        return false
    replayCallback := Func("ME_WheelInput_SendReplay")
    return ME_RunWithSyntheticInput(replayCallback, direction)
}

ME_WheelInput_SendReplay(direction) {
    if (direction == "Up")
        SendInput, {WheelUp}
    else if (direction == "Down")
        SendInput, {WheelDown}
    else
        return false
    return true
}

ME_WheelInput_Cleanup() {
    global ME_State
    state := ME_State.WheelInput
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true

    criterionCallback := state.CriterionCallback
    wheelUpHotkey := state.WheelUpHotkey
    wheelDownHotkey := state.WheelDownHotkey
    if (IsObject(criterionCallback)) {
        Hotkey, If, % criterionCallback
        if (state.WheelUpRegistered)
            Hotkey, % wheelUpHotkey, Off, UseErrorLevel
        if (state.WheelDownRegistered)
            Hotkey, % wheelDownHotkey, Off, UseErrorLevel
        Hotkey, If
    } else {
        Hotkey, If
    }

    state.WheelUpRegistered := false
    state.WheelDownRegistered := false
    state.CriterionCallback := false
    state.WheelUpCallback := false
    state.WheelDownCallback := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; MouseGestureL統合入口 / Wheelルーター骨格
; -----------------------------------------------------------------------------

ME_MouseGestureL_WheelEntry(direction, steps := 1) {
    ; MouseGestureL側はtrueなら消費、falseなら通常Wheel継続として扱える境界。
    input := {Direction: direction, Steps: steps, Tick: A_TickCount}
    return ME_RouteWheel(input)
}

ME_RouteWheel(input) {
    global ME_State
    if (!ME_CanRouteMouseInput())
        return false
    if (ME_State.SyntheticInputDepth > 0)
        return false

    ; 優先順位どおり最初にhandledとなった1機能だけで終了する。
    if (ME_HandleDedicatedWheel(input))
        return true
    return false ; 通常WheelはMouseGestureL/OS側に通す。
}

ME_CanRouteMouseInput() {
    global ME_State
    if (!ME_State.AcceptingInput || ME_State.CleanupStarted)
        return false
    return ME_MouseGestureL_AllowsInput()
}

ME_MouseGestureL_AllowsInput() {
    global MG_Enabled, MG_IsEdit
    ; MouseGestureL 1.41との接点をここへ限定する。値は参照のみで変更しない。
    ; 未初期化状態を独自推測せず、ホストが公開する真偽値をそのまま評価する。
    return (MG_Enabled && !MG_IsEdit) ? true : false
}

ME_MouseGestureL_IsEditMode() {
    global MG_IsEdit
    ; 公式1.41のプラグインincludeは実行側と設定編集側の両方で行われる。
    return MG_IsEdit ? true : false
}

ME_HandleDedicatedWheel(input) {
    if (ME_Taskbar_HandleWheel(input))
        return true
    if (ME_TrayWheelVolume_HandleWheel(input))
        return true
    if (ME_TabSwitch_HandleWheel(input))
        return true
    if (ME_ExplorerViewMode_HandleWheel(input))
        return true
    if (ME_SpecialScrollbarScroll_HandleWheel(input))
        return true
    if (ME_BrowserDragScroll_HandleWheel(input))
        return true
    return false
}

; -----------------------------------------------------------------------------
; AccelScroll（native physical wheel + SendInput synthetic extra）
; -----------------------------------------------------------------------------

ME_InitializeAccelScroll() {
    global ME_Config, ME_State
    state := ME_State.AccelScroll
    if (state.Initialized)
        return true
    if (state.CleanupStarted || ME_State.CleanupStarted)
        return false

    ME_AccelScroll_Reset()
    state.Sending := false
    if (!ME_Config.EnableFunction.AccelScroll || ME_MouseGestureL_IsEditMode()) {
        state.Initialized := true
        return true
    }

    state.CriterionCallback := Func("ME_AccelScroll_ShouldHandle")
    state.ModifierCriterionCallback := Func("ME_AccelScroll_ShouldResetForModifier")
    state.WheelUpCallback := Func("ME_AccelScroll_OnWheelUp")
    state.WheelDownCallback := Func("ME_AccelScroll_OnWheelDown")
    state.ModifierWheelCallback := Func("ME_AccelScroll_OnModifierWheel")
    criterionCallback := state.CriterionCallback
    modifierCriterionCallback := state.ModifierCriterionCallback
    wheelUpCallback := state.WheelUpCallback
    wheelDownCallback := state.WheelDownCallback
    modifierWheelCallback := state.ModifierWheelCallback
    wheelUpHotkey := state.WheelUpHotkey
    wheelDownHotkey := state.WheelDownHotkey
    modifierWheelUpHotkey := state.ModifierWheelUpHotkey
    modifierWheelDownHotkey := state.ModifierWheelDownHotkey

    registrationFailed := false
    Hotkey, If, % criterionCallback
    Hotkey, % wheelUpHotkey, % wheelUpCallback, On UseErrorLevel
    if (ErrorLevel)
        registrationFailed := true
    else
        state.WheelUpRegistered := true
    if (!registrationFailed) {
        Hotkey, % wheelDownHotkey, % wheelDownCallback, On UseErrorLevel
        if (ErrorLevel)
            registrationFailed := true
        else
            state.WheelDownRegistered := true
    }
    if (!registrationFailed) {
        Hotkey, If, % modifierCriterionCallback
        Hotkey, % modifierWheelUpHotkey, % modifierWheelCallback, On UseErrorLevel
        if (ErrorLevel)
            registrationFailed := true
        else
            state.ModifierWheelUpRegistered := true
    }
    if (!registrationFailed) {
        Hotkey, % modifierWheelDownHotkey, % modifierWheelCallback, On UseErrorLevel
        if (ErrorLevel)
            registrationFailed := true
        else
            state.ModifierWheelDownRegistered := true
    }
    Hotkey, If

    if (registrationFailed) {
        Hotkey, If, % criterionCallback
        if (state.WheelUpRegistered)
            Hotkey, % wheelUpHotkey, Off, UseErrorLevel
        if (state.WheelDownRegistered)
            Hotkey, % wheelDownHotkey, Off, UseErrorLevel
        Hotkey, If, % modifierCriterionCallback
        if (state.ModifierWheelUpRegistered)
            Hotkey, % modifierWheelUpHotkey, Off, UseErrorLevel
        if (state.ModifierWheelDownRegistered)
            Hotkey, % modifierWheelDownHotkey, Off, UseErrorLevel
        Hotkey, If
        state.WheelUpRegistered := false
        state.WheelDownRegistered := false
        state.ModifierWheelUpRegistered := false
        state.ModifierWheelDownRegistered := false
        state.CriterionCallback := false
        state.ModifierCriterionCallback := false
        state.WheelUpCallback := false
        state.WheelDownCallback := false
        state.ModifierWheelCallback := false
        state.Initialized := false
        ME_AccelScroll_Reset()
        return false
    }
    state.Initialized := true
    return true
}

ME_AccelScroll_ShouldHandle() {
    global ME_Config, ME_State
    state := ME_State.AccelScroll
    if (!state.Initialized || state.CleanupStarted || ME_State.CleanupStarted
        || !ME_State.AcceptingInput || !ME_Config.EnableFunction.AccelScroll
        || state.Sending || ME_State.SyntheticInputDepth > 0)
        return false
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
        || GetKeyState("MButton", "P") || GetKeyState("XButton1", "P")
        || GetKeyState("XButton2", "P")) {
        ME_AccelScroll_Reset()
        return false
    }
    return true
}

ME_AccelScroll_ShouldResetForModifier() {
    global ME_Config, ME_State
    state := ME_State.AccelScroll
    if (!state.Initialized || state.CleanupStarted || ME_State.CleanupStarted
        || !ME_State.AcceptingInput || !ME_Config.EnableFunction.AccelScroll
        || state.Sending || ME_State.SyntheticInputDepth > 0)
        return false
    return (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P")
        || GetKeyState("Alt", "P") || GetKeyState("LWin", "P")
        || GetKeyState("RWin", "P")) ? true : false
}

ME_AccelScroll_OnWheelUp() {
    Critical, On
    ME_AccelScroll_HandlePhysicalWheel("Up", A_EventInfo)
}

ME_AccelScroll_OnWheelDown() {
    Critical, On
    ME_AccelScroll_HandlePhysicalWheel("Down", A_EventInfo)
}

ME_AccelScroll_OnModifierWheel() {
    Critical, On
    ME_AccelScroll_Reset()
}

ME_AccelScroll_HandlePhysicalWheel(direction, physicalAmount) {
    global ME_Config, ME_State
    state := ME_State.AccelScroll
    if (!state.Initialized || state.CleanupStarted || ME_State.CleanupStarted
        || !ME_State.AcceptingInput || !ME_Config.EnableFunction.AccelScroll
        || state.Sending || ME_State.SyntheticInputDepth > 0
        || !ME_MouseGestureL_AllowsInput()) {
        ME_AccelScroll_Reset()
        return false
    }
    if (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P")
        || GetKeyState("Alt", "P") || GetKeyState("LWin", "P")
        || GetKeyState("RWin", "P") || GetKeyState("LButton", "P")
        || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
        || GetKeyState("XButton1", "P") || GetKeyState("XButton2", "P")) {
        ME_AccelScroll_Reset()
        return false
    }

    amount := physicalAmount + 0
    if (amount <= 0 || !(direction == "Up" || direction == "Down")
        || !ME_GetCursorScreenPoint(screenX, screenY)) {
        ME_AccelScroll_Reset()
        return false
    }
    targetHwnd := ME_WindowFromScreenPoint(screenX, screenY)
    if (!targetHwnd || !DllCall("User32\IsWindow", "Ptr", targetHwnd, "Int")) {
        ME_AccelScroll_Reset()
        return false
    }
    WinGet, processName, ProcessName, ahk_id %targetHwnd%
    processName := ME_Lower(Trim(processName))
    if (processName = "") {
        ME_AccelScroll_Reset()
        return false
    }
    excludeExe := ME_Config.AccelScroll.ExcludeExe
    if (IsObject(excludeExe) && IsObject(excludeExe.Lookup)
        && excludeExe.Lookup.HasKey(processName)) {
        ME_AccelScroll_Reset()
        return false
    }

    currentTick := A_TickCount
    if (state.LastDir = "" || !(state.LastDir == direction)) {
        ME_AccelScroll_Seed(direction, currentTick)
        return false
    }
    dt := currentTick - state.LastTick
    if (dt <= 0 || dt > 250) {
        ME_AccelScroll_Seed(direction, currentTick)
        return false
    }

    nextSpeed := 1000 * amount / dt
    speed := (state.PrevSpeed + nextSpeed) / 2
    state.LastDir := direction
    state.LastTick := currentTick
    state.PrevSpeed := nextSpeed
    throttle := ME_AccelScroll_CalculateThrottle(speed)
    extra := (throttle - 1) * amount
    if (extra > 64)
        extra := 64
    if (extra <= 0)
        return false
    return ME_AccelScroll_SendExtra(direction, extra)
}

ME_AccelScroll_CalculateThrottle(speed) {
    global ME_Config
    config := ME_Config.AccelScroll
    if (speed < config.MinWheelSpeed)
        return 1
    if (speed >= config.MaxWheelSpeed)
        return config.MaxThrottle
    throttle := Floor(config.MinThrottle
        + (speed - config.MinWheelSpeed) * (config.MaxThrottle - config.MinThrottle)
            / (config.MaxWheelSpeed - config.MinWheelSpeed))
    if (throttle > config.MaxThrottle)
        throttle := config.MaxThrottle
    return throttle
}

ME_AccelScroll_SendExtra(direction, extra) {
    global ME_State
    if (extra <= 0 || !(direction == "Up" || direction == "Down"))
        return false
    state := ME_State.AccelScroll
    succeeded := false
    state.Sending := true
    ME_BeginSyntheticInput()
    try {
        if (direction == "Up")
            SendInput, {WheelUp %extra%}
        else
            SendInput, {WheelDown %extra%}
        succeeded := true
    } catch error {
        succeeded := false
    } finally {
        ME_EndSyntheticInput()
        state.Sending := false
    }
    return succeeded
}

ME_AccelScroll_Seed(direction, tick) {
    global ME_State
    state := ME_State.AccelScroll
    state.LastDir := direction
    state.LastTick := tick
    state.PrevSpeed := 0
}

ME_AccelScroll_Reset() {
    global ME_State
    state := ME_State.AccelScroll
    state.LastDir := ""
    state.LastTick := 0
    state.PrevSpeed := 0
}

ME_AccelScroll_Cleanup() {
    global ME_State
    state := ME_State.AccelScroll
    if (state.CleanupStarted)
        return
    state.CleanupStarted := true

    criterionCallback := state.CriterionCallback
    modifierCriterionCallback := state.ModifierCriterionCallback
    wheelUpHotkey := state.WheelUpHotkey
    wheelDownHotkey := state.WheelDownHotkey
    modifierWheelUpHotkey := state.ModifierWheelUpHotkey
    modifierWheelDownHotkey := state.ModifierWheelDownHotkey
    if (IsObject(criterionCallback)) {
        Hotkey, If, % criterionCallback
        if (state.WheelUpRegistered)
            Hotkey, % wheelUpHotkey, Off, UseErrorLevel
        if (state.WheelDownRegistered)
            Hotkey, % wheelDownHotkey, Off, UseErrorLevel
        Hotkey, If
    } else {
        Hotkey, If
    }
    if (IsObject(modifierCriterionCallback)) {
        Hotkey, If, % modifierCriterionCallback
        if (state.ModifierWheelUpRegistered)
            Hotkey, % modifierWheelUpHotkey, Off, UseErrorLevel
        if (state.ModifierWheelDownRegistered)
            Hotkey, % modifierWheelDownHotkey, Off, UseErrorLevel
        Hotkey, If
    } else {
        Hotkey, If
    }

    state.WheelUpRegistered := false
    state.WheelDownRegistered := false
    state.ModifierWheelUpRegistered := false
    state.ModifierWheelDownRegistered := false
    state.CriterionCallback := false
    state.ModifierCriterionCallback := false
    state.WheelUpCallback := false
    state.WheelDownCallback := false
    state.ModifierWheelCallback := false
    ME_AccelScroll_Reset()
    state.Sending := false
    state.Initialized := false
}


; -----------------------------------------------------------------------------
; synthetic input 再入防止
; -----------------------------------------------------------------------------

ME_BeginSyntheticInput() {
    global ME_State
    ME_State.SyntheticInputDepth += 1
    return ME_State.SyntheticInputDepth
}

ME_EndSyntheticInput() {
    global ME_State
    if (ME_State.SyntheticInputDepth > 0)
        ME_State.SyntheticInputDepth -= 1
    return ME_State.SyntheticInputDepth
}

ME_RunWithSyntheticInput(callback, parameters*) {
    ; 合成処理は将来この境界を使う。例外時もdepthを必ず戻す。
    if (!IsObject(callback)) {
        if (!IsFunc(callback))
            return false
        callback := Func(callback)
    }
    ME_BeginSyntheticInput()
    try {
        result := callback.Call(parameters*)
    } catch error {
        ME_EndSyntheticInput()
        throw error
    }
    ME_EndSyntheticInput()
    return result
}


; -----------------------------------------------------------------------------
; Debug / Cleanup
; -----------------------------------------------------------------------------

ME_Debug(message) {
    global ME_Config, ME_Product
    if (!IsObject(ME_Config) || !IsObject(ME_Config.General) || !ME_Config.General.Debug)
        return
    OutputDebug, % "[" . ME_Product.Name . "] " . message
}

ME_RegisterTimerForCleanup(timerName) {
    global ME_State
    ; Phase 2以降で開始したtimer名だけを登録する。
    ME_State.Timers.Push(timerName)
}

MouseExtension_OnExit(exitReason, exitCode) {
    ME_Cleanup()
    return 0
}

ME_Cleanup() {
    global ME_State
    if (ME_State.CleanupStarted)
        return
    ME_State.CleanupStarted := true

    ; 1. 新規処理受付停止
    ME_State.AcceptingInput := false

    ; 2. 登録済みtimer停止
    ME_StopRegisteredTimers()
    ME_VolumeOverlay_Cleanup()

    ; 3. 一時入力状態解除（入れ子深度も終了時は強制的に0へ戻す）
    ME_State.SyntheticInputDepth := 0

    ; 4. Wheel hotkey停止とFunction Object参照破棄
    ME_AccelScroll_Cleanup()
    ME_WheelInput_Cleanup()

    ; 5. Dedicated Wheelの短寿命candidate破棄
    ME_TrayMiddleClickMute_Cleanup()
    ME_TrayWheelVolume_Cleanup()
    ME_Taskbar_Cleanup()
    ME_BrowserDragScroll_Cleanup()
    ME_SpecialScrollbarScroll_Cleanup()
    ME_ExplorerViewMode_Cleanup()
    ME_TabSwitch_Cleanup()

    ; 6. MoveDisabledWindowのdrag破棄とcallback参照破棄
    ME_MoveDisabledWindow_Cleanup()

    ; 7. OpenExeFolderの入力受付解除とcallback参照破棄
    ME_OpenExeFolder_Cleanup()

    ; 8. AlwaysOnTopの枠破棄、所有Topmost解除、状態破棄
    ME_AlwaysOnTop_Cleanup()

    ; 9. UIA / COM解放
    ME_UIA_Cleanup()
    ME_Native_Cleanup()

    ; 10. cache/state破棄
    ME_ClearHitTestCache()
}

ME_StopRegisteredTimers() {
    global ME_State
    for _, timerName in ME_State.Timers
        ; function object timerも内部参照ごと解放できるDeleteを使用する。
        SetTimer, %timerName%, Delete
    ME_State.Timers := []
}
