# NBK Anti-Spoiler

NBK Anti-Spoiler adds local spoiler protection for WoW chat to NerzorsBlacklistKeeper.
The bundled GTA VI profile checks German and English names, keywords, critical plot events and short conversation context.

The add-on offers Light, Medium, High and Context levels, manual and temporary player mutes,
and spoiler markers with encoded export. You can find the settings
and the list of hidden players under `/nbk config` in the **Anti-Spoiler** tab.

## Installation

1. Install and enable NerzorsBlacklistKeeper and its required data module.
2. Extract the release ZIP. The `NerzorsBlacklistKeeper_AntiSpoiler` folder goes directly into `Interface/AddOns`.
3. Start WoW, enable the add-on and choose **Enable protection** in the introduction.

Version `0.1.0` is based on the in-game verified development build `0.0.11-dev`. Tested clients are Retail 12.1.5, Retail 12.1.7 and Forever 1.60.1.
Detection uses local rules and can produce false positives and miss spoilers. Levels and chat types can be configured individually.

## Reporting spoilers

Right-click a name in chat, then **NBK - ANTI SPOILER → Mark as spoiler …**. Review the excerpt, remove anything private and save it as a marker. Under **My spoiler markers**, select the entries you want and choose **Create export**. Paste the copied `NBKAS1.…` string into a GitHub issue. Keep the title as spoiler-free as possible.

## Commands

| Command | Function |
| --- | --- |
| `/nbkspoiler intro` | Open the introduction |
| `/nbkspoiler muted` | Manage player mutes and transfer them to NBK |
| `/nbkspoiler mark` | Pick a recently received chat line to mark |
| `/nbkspoiler markers` | Manage and export saved markers |
