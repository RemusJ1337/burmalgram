import Foundation
import SGAppGroupIdentifier
import SGLogging

let APP_GROUP_IDENTIFIER = sgAppGroupIdentifier()

public class SGSimpleSettings {
    
    public static let shared = SGSimpleSettings()
    
    private init() {
        setDefaultValues()
        migrate()
        preCacheValues()
    }
    
    private func setDefaultValues() {
        UserDefaults.standard.register(defaults: SGSimpleSettings.defaultValues)
        // Just in case group defaults will be nil
        UserDefaults.standard.register(defaults: SGSimpleSettings.groupDefaultValues)
        if let groupUserDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) {
            groupUserDefaults.register(defaults: SGSimpleSettings.groupDefaultValues)
        }
    }
    
    private func migrate() {
        let showRepostToStoryMigrationKey = "migrated_\(Keys.showRepostToStory.rawValue)"
        if let groupUserDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) {
            if !groupUserDefaults.bool(forKey: showRepostToStoryMigrationKey) {
                self.showRepostToStoryV2 = self.showRepostToStory
                groupUserDefaults.set(true, forKey: showRepostToStoryMigrationKey)
                SGLogger.shared.log("SGSimpleSettings", "Migrated showRepostToStory. \(self.showRepostToStory) -> \(self.showRepostToStoryV2)")
            }
        } else {
            SGLogger.shared.log("SGSimpleSettings", "Unable to migrate showRepostToStory. Shared UserDefaults suite is not available for '\(APP_GROUP_IDENTIFIER)'.")
        }

        let chatListLinesMigrationKey = "migrated_\(Keys.chatListLines.rawValue)"
        if !UserDefaults.standard.bool(forKey: chatListLinesMigrationKey) {
            let legacyCompactMessagePreviewKey = "compactMessagePreview"
            if UserDefaults.standard.object(forKey: legacyCompactMessagePreviewKey) != nil {
                if UserDefaults.standard.bool(forKey: legacyCompactMessagePreviewKey) {
                    self.chatListLines = ChatListLines.one.rawValue
                }
                UserDefaults.standard.removeObject(forKey: legacyCompactMessagePreviewKey)
                SGLogger.shared.log("SGSimpleSettings", "Migrated compactMessagePreview -> chatListLines. \(self.chatListLines)")
            }
            UserDefaults.standard.set(true, forKey: chatListLinesMigrationKey)
        }
    }
    
    private func preCacheValues() {
        // let dispatchGroup = DispatchGroup()

        let tasks = [
//            { let _ = self.allChatsFolderPositionOverride },
            { let _ = self.tabBarSearchEnabled },
            { let _ = self.allChatsHidden },
            { let _ = self.hideTabBar },
            { let _ = self.bottomTabStyle },
            { let _ = self.compactChatList },
            { let _ = self.chatListLines },
            { let _ = self.compactFolderNames },
            { let _ = self.disableSwipeToRecordStory },
            { let _ = self.rememberLastFolder },
            { let _ = self.quickTranslateButton },
            { let _ = self.stickerSize },
            { let _ = self.stickerTimestamp },
            { let _ = self.hideReactions },
            { let _ = self.disableGalleryCamera },
            { let _ = self.disableSendAsButton },
            { let _ = self.disableSnapDeletionEffect },
            { let _ = self.startTelescopeWithRearCam },
            { let _ = self.hideRecordingButton },
            { let _ = self.inputToolbar },
            { let _ = self.dismissedSGSuggestions },
            { let _ = self.customAppBadge },
            { let _ = self.exteraUiStyle },
            { let _ = self.pillStackShowWeather },
            { let _ = self.pillStackInfiniteScroll },
            { let _ = self.removeMessageTail },
            { let _ = self.avatarCorners },
            { let _ = self.dividerStyle },
            { let _ = self.forceBlur },
            { let _ = self.glassOutlineStyle },
            { let _ = self.springAnimations },
            { let _ = self.centerTitle },
            { let _ = self.hideDialogsSearchBar }
        ]

        tasks.forEach { task in
            DispatchQueue.global(qos: .background).async(/*group: dispatchGroup*/) {
                task()
            }
        }

        // dispatchGroup.notify(queue: DispatchQueue.main) {}
    }
    
    public func synchronizeShared() {
        if let groupUserDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) {
            groupUserDefaults.synchronize()
        }
    }
    
    public enum Keys: String, CaseIterable {
        case hidePhoneInSettings
        case showTabNames
        case startTelescopeWithRearCam
        case accountColorsSaturation
        case uploadSpeedBoost
        case downloadSpeedBoost
        case bottomTabStyle
        case rememberLastFolder
        case lastAccountFolders
        case localDNSForProxyHost
        case sendLargePhotos
        case outgoingPhotoQuality
        case storyStealthMode
        case canUseStealthMode
        case disableSwipeToRecordStory
        case quickTranslateButton
        case outgoingLanguageTranslation
        case hideReactions
        case showRepostToStory
        case showRepostToStoryV2
        case contextShowSelectFromUser
        case contextShowSaveToCloud
        case contextShowRestrict
        // case contextShowBan
        case contextShowHideForwardName
        case contextShowReport
        case contextShowReply
        case contextShowPin
        case contextShowSaveMedia
        case contextShowMessageReplies
        case contextShowJson
        case disableScrollToNextChannel
        case disableScrollToNextTopic
        case disableChatSwipeOptions
        case disableDeleteChatSwipeOption
        case disableGalleryCamera
        case disableGalleryCameraPreview
        case disableSendAsButton
        case disableSnapDeletionEffect
        case stickerSize
        case stickerTimestamp
        case hideRecordingButton
        case hideTabBar
        case showDC
        case showCreationDate
        case showRegDate
        case regDateCache
        case compactChatList
        case chatListLines
        case compactFolderNames
        case allChatsTitleLengthOverride
//        case allChatsFolderPositionOverride
        case allChatsHidden
        case defaultEmojisFirst
        case messageDoubleTapActionOutgoing
        case wideChannelPosts
        case forceEmojiTab
        case forceBuiltInMic
        case secondsInMessages
        case hideChannelBottomButton
        case forceSystemSharing
        case confirmCalls
        case videoPIPSwipeDirection
        case legacyNotificationsFix
        case messageFilterKeywords
        case inputToolbar
        case pinnedMessageNotifications
        case mentionsAndRepliesNotifications
        case primaryUserId
        case status
        case dismissedSGSuggestions
        case duckyAppIconAvailable
        case transcriptionBackend
        case translationBackend
        case customAppBadge
        case canUseNY
        case nyStyle
        case wideTabBar
        case tabBarSearchEnabled
        case hideStories
        case warnOnStoriesOpen
        case showProfileId
        case sendWithReturnKey
        case fakePremium
        case customFont
        case customPhoneNumber
        case disableForwardRestriction
        case fixFilePicker
        case fakeProfileColor
        case fakeProfileBackgroundEmojiId
        case fakeNameColor
        case fakeBackgroundEmojiId
        case fakeEmojiStatusFileId
        case burmalgramTheme
        case useDefaultThemeColors
        case fakePremiumShowBadge
        case fakePremiumVoiceToText
        case fakePremiumReactions
        case fakePremiumColors
        case exteraUiStyle
        case pillStackEnabled
        case pillStackShowCrypto
        case pillStackShowCache
        case pillStackShowProxy
        case cleanUrlsEnabled
        case zalgoFilterEnabled
        case customThemeEnabled
        case customThemePreset
        case customThemeBgColor1
        case customThemeBgColor2
        case customThemeBubbleColor1
        case customThemeBubbleColor2
        case customThemeIncomingBubbleColor
        case customThemeTextColor
        case customThemeStarsEnabled
        case customThemeStarsColor
        case customThemeTextShimmer
        case customThemeTextShimmerMode
        case customThemeTextShimmerColor
        case customThemeTextShimmerSpeed
        case pillStackShowWeather
        case pillStackInfiniteScroll
        case removeMessageTail
        case avatarCorners
        case dividerStyle
        case forceBlur
        case glassOutlineStyle
        case springAnimations
        case centerTitle
        case hideDialogsSearchBar
    }
    
    public enum DownloadSpeedBoostValues: String, CaseIterable {
        case none
        case medium
        case maximum
    }
    
    public enum BottomTabStyleValues: String, CaseIterable {
        case telegram
        case ios
    }
    
    public enum AllChatsTitleLengthOverride: String, CaseIterable {
        case none
        case short
        case long
    }
    
    public enum AllChatsFolderPositionOverride: String, CaseIterable {
        case none
        case last
        case hidden
    }

    public enum ChatListLines: String, CaseIterable {
        case three = "3"
        case two = "2"
        case one = "1"

        public static let defaultValue: ChatListLines = .three
    }
    
    public enum MessageDoubleTapAction: String, CaseIterable {
        case `default`
        case none
        case edit
    }
    
    public enum VideoPIPSwipeDirection: String, CaseIterable {
        case up
        case down
        case none
    }

    public enum TranscriptionBackend: String, CaseIterable {
        case `default`
        case apple
    }

    public enum TranslationBackend: String, CaseIterable {
        case `default`
        case gtranslate
        case system
        // Make sure to update TranslationConfiguration
    }
        
    public enum PinnedMessageNotificationsSettings: String, CaseIterable {
        case `default`
        case silenced
        case disabled
    }
    
    public enum MentionsAndRepliesNotificationsSettings: String, CaseIterable {
        case `default`
        case silenced
        case disabled
    }

    public enum NYStyle: String, CaseIterable {
        case `default`
        case snow
        case lightning
        case stars
        case sparks
        case metal
    }
    
    public static let defaultValues: [String: Any] = [
        Keys.hidePhoneInSettings.rawValue: true,
        Keys.showTabNames.rawValue: true,
        Keys.startTelescopeWithRearCam.rawValue: false,
        Keys.accountColorsSaturation.rawValue: 100,
        Keys.uploadSpeedBoost.rawValue: false,
        Keys.downloadSpeedBoost.rawValue: DownloadSpeedBoostValues.none.rawValue,
        Keys.rememberLastFolder.rawValue: false,
        Keys.bottomTabStyle.rawValue: BottomTabStyleValues.telegram.rawValue,
        Keys.lastAccountFolders.rawValue: [:],
        Keys.localDNSForProxyHost.rawValue: false,
        Keys.sendLargePhotos.rawValue: false,
        Keys.outgoingPhotoQuality.rawValue: 70,
        Keys.storyStealthMode.rawValue: false,
        Keys.canUseStealthMode.rawValue: true,
        Keys.disableSwipeToRecordStory.rawValue: false,
        Keys.quickTranslateButton.rawValue: false,
        Keys.outgoingLanguageTranslation.rawValue: [:],
        Keys.hideReactions.rawValue: false,
        Keys.showRepostToStory.rawValue: true,
        Keys.contextShowSelectFromUser.rawValue: true,
        Keys.contextShowSaveToCloud.rawValue: true,
        Keys.contextShowRestrict.rawValue: true,
        // Keys.contextShowBan.rawValue: true,
        Keys.contextShowHideForwardName.rawValue: true,
        Keys.contextShowReport.rawValue: true,
        Keys.contextShowReply.rawValue: true,
        Keys.contextShowPin.rawValue: true,
        Keys.contextShowSaveMedia.rawValue: true,
        Keys.contextShowMessageReplies.rawValue: true,
        Keys.contextShowJson.rawValue: false,
        Keys.disableScrollToNextChannel.rawValue: false,
        Keys.disableScrollToNextTopic.rawValue: false,
        Keys.disableChatSwipeOptions.rawValue: false,
        Keys.disableDeleteChatSwipeOption.rawValue: false,
        Keys.disableGalleryCamera.rawValue: false,
        Keys.disableGalleryCameraPreview.rawValue: false,
        Keys.disableSendAsButton.rawValue: false,
        Keys.disableSnapDeletionEffect.rawValue: false,
        Keys.stickerSize.rawValue: 100,
        Keys.stickerTimestamp.rawValue: true,
        Keys.hideRecordingButton.rawValue: false,
        Keys.hideTabBar.rawValue: false,
        Keys.showDC.rawValue: false,
        Keys.showCreationDate.rawValue: true,
        Keys.showRegDate.rawValue: true,
        Keys.regDateCache.rawValue: [:],
        Keys.compactChatList.rawValue: false,
        Keys.chatListLines.rawValue: ChatListLines.defaultValue.rawValue,
        Keys.compactFolderNames.rawValue: false,
        Keys.allChatsTitleLengthOverride.rawValue: AllChatsTitleLengthOverride.none.rawValue,
//        Keys.allChatsFolderPositionOverride.rawValue: AllChatsFolderPositionOverride.none.rawValue
        Keys.allChatsHidden.rawValue: false,
        Keys.defaultEmojisFirst.rawValue: false,
        Keys.messageDoubleTapActionOutgoing.rawValue: MessageDoubleTapAction.default.rawValue,
        Keys.wideChannelPosts.rawValue: false,
        Keys.forceEmojiTab.rawValue: false,
        Keys.hideChannelBottomButton.rawValue: false,
        Keys.secondsInMessages.rawValue: false,
        Keys.forceSystemSharing.rawValue: false,
        Keys.confirmCalls.rawValue: true,
        Keys.videoPIPSwipeDirection.rawValue: VideoPIPSwipeDirection.up.rawValue,
        Keys.messageFilterKeywords.rawValue: [],
        Keys.inputToolbar.rawValue: false,
        Keys.primaryUserId.rawValue: "",
        Keys.dismissedSGSuggestions.rawValue: [],
        Keys.duckyAppIconAvailable.rawValue: true,
        Keys.transcriptionBackend.rawValue: TranscriptionBackend.default.rawValue,
        Keys.translationBackend.rawValue: TranslationBackend.default.rawValue,
        Keys.customAppBadge.rawValue: "",
        Keys.canUseNY.rawValue: false,
        Keys.nyStyle.rawValue: NYStyle.default.rawValue,
        Keys.wideTabBar.rawValue: false,
        Keys.tabBarSearchEnabled.rawValue: true,
        Keys.hideStories.rawValue: false,
        Keys.warnOnStoriesOpen.rawValue: false,
        Keys.showProfileId.rawValue: true,
        Keys.sendWithReturnKey.rawValue: false,
        Keys.fakePremium.rawValue: false,
        Keys.customFont.rawValue: "default",
        Keys.customPhoneNumber.rawValue: "",
        Keys.disableForwardRestriction.rawValue: false,
        Keys.fixFilePicker.rawValue: false,
        Keys.fakeProfileColor.rawValue: -1 as Int32,
        Keys.fakeProfileBackgroundEmojiId.rawValue: 0 as Int64,
        Keys.fakeNameColor.rawValue: -1 as Int32,
        Keys.fakeBackgroundEmojiId.rawValue: 0 as Int64,
        Keys.fakeEmojiStatusFileId.rawValue: 0 as Int64,
        Keys.burmalgramTheme.rawValue: "default",
        Keys.useDefaultThemeColors.rawValue: false,
        Keys.fakePremiumShowBadge.rawValue: false,
        Keys.fakePremiumVoiceToText.rawValue: true,
        Keys.fakePremiumReactions.rawValue: true,
        Keys.fakePremiumColors.rawValue: true,
        Keys.exteraUiStyle.rawValue: "extera",
        Keys.pillStackEnabled.rawValue: true,
        Keys.pillStackShowCrypto.rawValue: true,
        Keys.pillStackShowCache.rawValue: true,
        Keys.pillStackShowProxy.rawValue: true,
        Keys.cleanUrlsEnabled.rawValue: true,
        Keys.zalgoFilterEnabled.rawValue: true,
        Keys.customThemeEnabled.rawValue: false,
        Keys.customThemePreset.rawValue: "custom",
        Keys.customThemeBgColor1.rawValue: "000C2A",
        Keys.customThemeBgColor2.rawValue: "001744",
        Keys.customThemeBubbleColor1.rawValue: "006CE6",
        Keys.customThemeBubbleColor2.rawValue: "00BCFF",
        Keys.customThemeIncomingBubbleColor.rawValue: "161C2E",
        Keys.customThemeTextColor.rawValue: "FFFFFF",
        Keys.customThemeStarsEnabled.rawValue: true,
        Keys.customThemeStarsColor.rawValue: "white",
        Keys.customThemeTextShimmer.rawValue: false,
        Keys.customThemeTextShimmerMode.rawValue: "single",
        Keys.customThemeTextShimmerColor.rawValue: "white",
        Keys.customThemeTextShimmerSpeed.rawValue: "normal",
        Keys.pillStackShowWeather.rawValue: true,
        Keys.pillStackInfiniteScroll.rawValue: false,
        Keys.removeMessageTail.rawValue: true,
        Keys.avatarCorners.rawValue: "squircle",
        Keys.dividerStyle.rawValue: "hidden",
        Keys.forceBlur.rawValue: true,
        Keys.glassOutlineStyle.rawValue: "glare",
        Keys.springAnimations.rawValue: true,
        Keys.centerTitle.rawValue: false,
        Keys.hideDialogsSearchBar.rawValue: false
    ]
    
    public static let groupDefaultValues: [String: Any] = [
        Keys.legacyNotificationsFix.rawValue: false,
        Keys.pinnedMessageNotifications.rawValue: PinnedMessageNotificationsSettings.default.rawValue,
        Keys.mentionsAndRepliesNotifications.rawValue: MentionsAndRepliesNotificationsSettings.default.rawValue,
        Keys.status.rawValue: 1,
        Keys.showRepostToStoryV2.rawValue: true,
        Keys.exteraUiStyle.rawValue: "extera",
        Keys.pillStackShowWeather.rawValue: true,
        Keys.pillStackInfiniteScroll.rawValue: false,
        Keys.removeMessageTail.rawValue: true,
        Keys.avatarCorners.rawValue: "squircle",
        Keys.dividerStyle.rawValue: "hidden",
        Keys.forceBlur.rawValue: true,
        Keys.glassOutlineStyle.rawValue: "glare",
        Keys.springAnimations.rawValue: true,
        Keys.centerTitle.rawValue: false,
        Keys.hideDialogsSearchBar.rawValue: false,
    ]
    
    @UserDefault(key: Keys.fakePremium.rawValue)
    public var fakePremium: Bool

    @UserDefault(key: Keys.customFont.rawValue)
    public var customFont: String

    @UserDefault(key: Keys.customPhoneNumber.rawValue)
    public var customPhoneNumber: String

    @UserDefault(key: Keys.disableForwardRestriction.rawValue)
    public var disableForwardRestriction: Bool

    @UserDefault(key: Keys.fixFilePicker.rawValue)
    public var fixFilePicker: Bool

    @UserDefault(key: Keys.fakeProfileColor.rawValue)
    public var fakeProfileColor: Int32

    @UserDefault(key: Keys.fakeProfileBackgroundEmojiId.rawValue)
    public var fakeProfileBackgroundEmojiId: Int64

    @UserDefault(key: Keys.fakeNameColor.rawValue)
    public var fakeNameColor: Int32

    @UserDefault(key: Keys.fakeBackgroundEmojiId.rawValue)
    public var fakeBackgroundEmojiId: Int64

    @UserDefault(key: Keys.fakeEmojiStatusFileId.rawValue)
    public var fakeEmojiStatusFileId: Int64

    @UserDefault(key: Keys.burmalgramTheme.rawValue)
    public var burmalgramTheme: String

    @UserDefault(key: Keys.useDefaultThemeColors.rawValue)
    public var useDefaultThemeColors: Bool

    @UserDefault(key: Keys.fakePremiumShowBadge.rawValue)
    public var fakePremiumShowBadge: Bool

    @UserDefault(key: Keys.fakePremiumVoiceToText.rawValue)
    public var fakePremiumVoiceToText: Bool

    @UserDefault(key: Keys.fakePremiumReactions.rawValue)
    public var fakePremiumReactions: Bool

    @UserDefault(key: Keys.fakePremiumColors.rawValue)
    public var fakePremiumColors: Bool

    @UserDefault(key: Keys.exteraUiStyle.rawValue)
    public var exteraUiStyle: String

    @UserDefault(key: Keys.pillStackEnabled.rawValue)
    public var pillStackEnabled: Bool

    @UserDefault(key: Keys.pillStackShowCrypto.rawValue)
    public var pillStackShowCrypto: Bool

    @UserDefault(key: Keys.pillStackShowCache.rawValue)
    public var pillStackShowCache: Bool

    @UserDefault(key: Keys.pillStackShowProxy.rawValue)
    public var pillStackShowProxy: Bool

    @UserDefault(key: Keys.cleanUrlsEnabled.rawValue)
    public var cleanUrlsEnabled: Bool

    @UserDefault(key: Keys.zalgoFilterEnabled.rawValue)
    public var zalgoFilterEnabled: Bool

    @UserDefault(key: Keys.customThemeEnabled.rawValue)
    public var customThemeEnabled: Bool

    @UserDefault(key: Keys.customThemePreset.rawValue)
    public var customThemePreset: String

    @UserDefault(key: Keys.customThemeBgColor1.rawValue)
    public var customThemeBgColor1: String

    @UserDefault(key: Keys.customThemeBgColor2.rawValue)
    public var customThemeBgColor2: String

    @UserDefault(key: Keys.customThemeBubbleColor1.rawValue)
    public var customThemeBubbleColor1: String

    @UserDefault(key: Keys.customThemeBubbleColor2.rawValue)
    public var customThemeBubbleColor2: String

    @UserDefault(key: Keys.customThemeIncomingBubbleColor.rawValue)
    public var customThemeIncomingBubbleColor: String

    @UserDefault(key: Keys.customThemeTextColor.rawValue)
    public var customThemeTextColor: String

    @UserDefault(key: Keys.customThemeStarsEnabled.rawValue)
    public var customThemeStarsEnabled: Bool

    @UserDefault(key: Keys.customThemeStarsColor.rawValue)
    public var customThemeStarsColor: String

    @UserDefault(key: Keys.customThemeTextShimmer.rawValue)
    public var customThemeTextShimmer: Bool

    @UserDefault(key: Keys.customThemeTextShimmerMode.rawValue)
    public var customThemeTextShimmerMode: String

    @UserDefault(key: Keys.customThemeTextShimmerColor.rawValue)
    public var customThemeTextShimmerColor: String

    @UserDefault(key: Keys.customThemeTextShimmerSpeed.rawValue)
    public var customThemeTextShimmerSpeed: String

    @UserDefault(key: Keys.pillStackShowWeather.rawValue)
    public var pillStackShowWeather: Bool

    @UserDefault(key: Keys.pillStackInfiniteScroll.rawValue)
    public var pillStackInfiniteScroll: Bool

    @UserDefault(key: Keys.removeMessageTail.rawValue)
    public var removeMessageTail: Bool

    @UserDefault(key: Keys.avatarCorners.rawValue)
    public var avatarCorners: String

    @UserDefault(key: Keys.dividerStyle.rawValue)
    public var dividerStyle: String

    @UserDefault(key: Keys.forceBlur.rawValue)
    public var forceBlur: Bool

    @UserDefault(key: Keys.glassOutlineStyle.rawValue)
    public var glassOutlineStyle: String

    @UserDefault(key: Keys.springAnimations.rawValue)
    public var springAnimations: Bool

    @UserDefault(key: Keys.centerTitle.rawValue)
    public var centerTitle: Bool

    @UserDefault(key: Keys.hideDialogsSearchBar.rawValue)
    public var hideDialogsSearchBar: Bool

    @UserDefault(key: Keys.hidePhoneInSettings.rawValue)
    public var hidePhoneInSettings: Bool
    
    @UserDefault(key: Keys.showTabNames.rawValue)
    public var showTabNames: Bool
    
    @UserDefault(key: Keys.startTelescopeWithRearCam.rawValue)
    public var startTelescopeWithRearCam: Bool
    
    @UserDefault(key: Keys.accountColorsSaturation.rawValue)
    public var accountColorsSaturation: Int32
    
    @UserDefault(key: Keys.uploadSpeedBoost.rawValue)
    public var uploadSpeedBoost: Bool
    
    @UserDefault(key: Keys.downloadSpeedBoost.rawValue)
    public var downloadSpeedBoost: String
    
    @UserDefault(key: Keys.rememberLastFolder.rawValue)
    public var rememberLastFolder: Bool
    
    // Disabled while Telegram is migrating to Glass
    // @UserDefault(key: Keys.bottomTabStyle.rawValue)
    public var bottomTabStyle: String {
        set {}
        get {
            return BottomTabStyleValues.ios.rawValue
        }
    }
    
    public var lastAccountFolders = UserDefaultsBackedDictionary<String, Int32>(userDefaultsKey: Keys.lastAccountFolders.rawValue, threadSafe: false)
    
    @UserDefault(key: Keys.localDNSForProxyHost.rawValue)
    public var localDNSForProxyHost: Bool
    
    @UserDefault(key: Keys.sendLargePhotos.rawValue)
    public var sendLargePhotos: Bool
    
    @UserDefault(key: Keys.outgoingPhotoQuality.rawValue)
    public var outgoingPhotoQuality: Int32

    @UserDefault(key: Keys.hideStories.rawValue)
    public var hideStories: Bool

    @UserDefault(key: Keys.warnOnStoriesOpen.rawValue)
    public var warnOnStoriesOpen: Bool
    
    @UserDefault(key: Keys.storyStealthMode.rawValue)
    public var storyStealthMode: Bool
    
    @UserDefault(key: Keys.canUseStealthMode.rawValue)
    public var canUseStealthMode: Bool    
    
    @UserDefault(key: Keys.disableSwipeToRecordStory.rawValue)
    public var disableSwipeToRecordStory: Bool   
    
    @UserDefault(key: Keys.quickTranslateButton.rawValue)
    public var quickTranslateButton: Bool
    
    public var outgoingLanguageTranslation = UserDefaultsBackedDictionary<String, String>(userDefaultsKey: Keys.outgoingLanguageTranslation.rawValue, threadSafe: false)
    
    @UserDefault(key: Keys.hideReactions.rawValue)
    public var hideReactions: Bool

    // @available(*, deprecated, message: "Use showRepostToStoryV2 instead")
    @UserDefault(key: Keys.showRepostToStory.rawValue)
    public var showRepostToStory: Bool

    @UserDefault(key: Keys.showRepostToStoryV2.rawValue, userDefaults: UserDefaults(suiteName: APP_GROUP_IDENTIFIER) ?? .standard)
    public var showRepostToStoryV2: Bool

    @UserDefault(key: Keys.contextShowRestrict.rawValue)
    public var contextShowRestrict: Bool

    /*@UserDefault(key: Keys.contextShowBan.rawValue)
    public var contextShowBan: Bool*/

    @UserDefault(key: Keys.contextShowSelectFromUser.rawValue)
    public var contextShowSelectFromUser: Bool

    @UserDefault(key: Keys.contextShowSaveToCloud.rawValue)
    public var contextShowSaveToCloud: Bool

    @UserDefault(key: Keys.contextShowHideForwardName.rawValue)
    public var contextShowHideForwardName: Bool

    @UserDefault(key: Keys.contextShowReport.rawValue)
    public var contextShowReport: Bool

    @UserDefault(key: Keys.contextShowReply.rawValue)
    public var contextShowReply: Bool

    @UserDefault(key: Keys.contextShowPin.rawValue)
    public var contextShowPin: Bool

    @UserDefault(key: Keys.contextShowSaveMedia.rawValue)
    public var contextShowSaveMedia: Bool

    @UserDefault(key: Keys.contextShowMessageReplies.rawValue)
    public var contextShowMessageReplies: Bool
    
    @UserDefault(key: Keys.contextShowJson.rawValue)
    public var contextShowJson: Bool
    
    @UserDefault(key: Keys.disableScrollToNextChannel.rawValue)
    public var disableScrollToNextChannel: Bool

    @UserDefault(key: Keys.disableScrollToNextTopic.rawValue)
    public var disableScrollToNextTopic: Bool

    @UserDefault(key: Keys.disableChatSwipeOptions.rawValue)
    public var disableChatSwipeOptions: Bool

    @UserDefault(key: Keys.disableDeleteChatSwipeOption.rawValue)
    public var disableDeleteChatSwipeOption: Bool

    @UserDefault(key: Keys.disableGalleryCamera.rawValue)
    public var disableGalleryCamera: Bool

    @UserDefault(key: Keys.disableGalleryCameraPreview.rawValue)
    public var disableGalleryCameraPreview: Bool

    @UserDefault(key: Keys.disableSendAsButton.rawValue)
    public var disableSendAsButton: Bool

    @UserDefault(key: Keys.disableSnapDeletionEffect.rawValue)
    public var disableSnapDeletionEffect: Bool
    
    @UserDefault(key: Keys.stickerSize.rawValue)
    public var stickerSize: Int32
    
    @UserDefault(key: Keys.stickerTimestamp.rawValue)
    public var stickerTimestamp: Bool    

    @UserDefault(key: Keys.hideRecordingButton.rawValue)
    public var hideRecordingButton: Bool
    
    @UserDefault(key: Keys.hideTabBar.rawValue)
    public var hideTabBar: Bool

    @UserDefault(key: Keys.showProfileId.rawValue)
    public var showProfileId: Bool
    
    @UserDefault(key: Keys.showDC.rawValue)
    public var showDC: Bool
    
    @UserDefault(key: Keys.showCreationDate.rawValue)
    public var showCreationDate: Bool

    @UserDefault(key: Keys.showRegDate.rawValue)
    public var showRegDate: Bool

    public var regDateCache = UserDefaultsBackedDictionary<String, Data>(userDefaultsKey: Keys.regDateCache.rawValue, threadSafe: false)
    
    @UserDefault(key: Keys.compactChatList.rawValue)
    public var compactChatList: Bool

    @UserDefault(key: Keys.chatListLines.rawValue)
    public var chatListLines: String

    @UserDefault(key: Keys.compactFolderNames.rawValue)
    public var compactFolderNames: Bool
    
    @UserDefault(key: Keys.allChatsTitleLengthOverride.rawValue)
    public var allChatsTitleLengthOverride: String
//    
//    @UserDefault(key: Keys.allChatsFolderPositionOverride.rawValue)
//    public var allChatsFolderPositionOverride: String
    @UserDefault(key: Keys.allChatsHidden.rawValue)
    public var allChatsHidden: Bool

    @UserDefault(key: Keys.defaultEmojisFirst.rawValue)
    public var defaultEmojisFirst: Bool
    
    @UserDefault(key: Keys.messageDoubleTapActionOutgoing.rawValue)
    public var messageDoubleTapActionOutgoing: String
    
    @UserDefault(key: Keys.wideChannelPosts.rawValue)
    public var wideChannelPosts: Bool

    @UserDefault(key: Keys.forceEmojiTab.rawValue)
    public var forceEmojiTab: Bool
    
    @UserDefault(key: Keys.forceBuiltInMic.rawValue)
    public var forceBuiltInMic: Bool
    
    @UserDefault(key: Keys.secondsInMessages.rawValue)
    public var secondsInMessages: Bool
    
    @UserDefault(key: Keys.hideChannelBottomButton.rawValue)
    public var hideChannelBottomButton: Bool

    @UserDefault(key: Keys.forceSystemSharing.rawValue)
    public var forceSystemSharing: Bool

    @UserDefault(key: Keys.confirmCalls.rawValue)
    public var confirmCalls: Bool
    
    @UserDefault(key: Keys.videoPIPSwipeDirection.rawValue)
    public var videoPIPSwipeDirection: String

    @UserDefault(key: Keys.legacyNotificationsFix.rawValue, userDefaults: UserDefaults(suiteName: APP_GROUP_IDENTIFIER) ?? .standard)
    public var legacyNotificationsFix: Bool
    
    @UserDefault(key: Keys.status.rawValue, userDefaults: UserDefaults(suiteName: APP_GROUP_IDENTIFIER) ?? .standard)
    public var status: Int64

    public var ephemeralStatus: Int64 = 1
    
    @UserDefault(key: Keys.messageFilterKeywords.rawValue)
    public var messageFilterKeywords: [String]
    
    @UserDefault(key: Keys.inputToolbar.rawValue)
    public var inputToolbar: Bool

    @UserDefault(key: Keys.sendWithReturnKey.rawValue)
    public var sendWithReturnKey: Bool
    
    @UserDefault(key: Keys.pinnedMessageNotifications.rawValue, userDefaults: UserDefaults(suiteName: APP_GROUP_IDENTIFIER) ?? .standard)
    public var pinnedMessageNotifications: String
    
    @UserDefault(key: Keys.mentionsAndRepliesNotifications.rawValue, userDefaults: UserDefaults(suiteName: APP_GROUP_IDENTIFIER) ?? .standard)
    public var mentionsAndRepliesNotifications: String
    
    @UserDefault(key: Keys.primaryUserId.rawValue)
    public var primaryUserId: String

    @UserDefault(key: Keys.dismissedSGSuggestions.rawValue)
    public var dismissedSGSuggestions: [String]

    @UserDefault(key: Keys.duckyAppIconAvailable.rawValue)
    public var duckyAppIconAvailable: Bool

    @UserDefault(key: Keys.transcriptionBackend.rawValue)
    public var transcriptionBackend: String

    @UserDefault(key: Keys.translationBackend.rawValue)
    public var translationBackend: String

    @UserDefault(key: Keys.customAppBadge.rawValue)
    public var customAppBadge: String

    @UserDefault(key: Keys.canUseNY.rawValue)
    public var canUseNY: Bool

    @UserDefault(key: Keys.nyStyle.rawValue)
    public var nyStyle: String

    @UserDefault(key: Keys.wideTabBar.rawValue)
    public var wideTabBar: Bool
    
    @UserDefault(key: Keys.tabBarSearchEnabled.rawValue)
    public var tabBarSearchEnabled: Bool
}

extension SGSimpleSettings {
    public var isStealthModeEnabled: Bool {
        return storyStealthMode && canUseStealthMode
    }
    
    public static func makeOutgoingLanguageTranslationKey(accountId: Int64, peerId: Int64) -> String {
        return "\(accountId):\(peerId)"
    }
}

extension SGSimpleSettings {
    public var translationBackendEnum: SGSimpleSettings.TranslationBackend {
        return TranslationBackend(rawValue: translationBackend) ?? .default
    }
    
    public var transcriptionBackendEnum: SGSimpleSettings.TranscriptionBackend {
        return TranscriptionBackend(rawValue: transcriptionBackend) ?? .default
    }
}

extension SGSimpleSettings {
    public var isNYEnabled: Bool {
        if customThemeEnabled && customThemeStarsEnabled {
            return true
        }
        return canUseNY && NYStyle(rawValue: nyStyle) != .default
    }
}

public func getSGDownloadPartSize(_ default: Int64, fileSize: Int64?) -> Int64 {
    let currentDownloadSetting = SGSimpleSettings.shared.downloadSpeedBoost
    // Increasing chunk size for small files make it worse in terms of overall download performance
    let smallFileSizeThreshold = 1 * 1024 * 1024 // 1 MB
    switch (currentDownloadSetting) {
        case SGSimpleSettings.DownloadSpeedBoostValues.medium.rawValue:
            if let fileSize, fileSize <= smallFileSizeThreshold {
                return `default`
            }
            return 512 * 1024
        case SGSimpleSettings.DownloadSpeedBoostValues.maximum.rawValue:
            if let fileSize, fileSize <= smallFileSizeThreshold {
                return `default`
            }
            return 1024 * 1024
        default:
            return `default`
    }
}

public func getSGMaxPendingParts(_ default: Int) -> Int {
    let currentDownloadSetting = SGSimpleSettings.shared.downloadSpeedBoost
    switch (currentDownloadSetting) {
        case SGSimpleSettings.DownloadSpeedBoostValues.medium.rawValue:
            return 8
        case SGSimpleSettings.DownloadSpeedBoostValues.maximum.rawValue:
            return 12
        default:
            return `default`
    }
}

public func sgUseShortAllChatsTitle(_ default: Bool) -> Bool {
    let currentOverride = SGSimpleSettings.shared.allChatsTitleLengthOverride
    switch (currentOverride) {
        case SGSimpleSettings.AllChatsTitleLengthOverride.short.rawValue:
            return true
        case SGSimpleSettings.AllChatsTitleLengthOverride.long.rawValue:
            return false
        default:
            return `default`
    }
}
