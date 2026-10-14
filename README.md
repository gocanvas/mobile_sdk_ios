# GoCanvas SDK for iOS

#### Table of contents:

- [Introduction](#introduction)
- [Installation](#installation)
- [Migrating from 6.2 and earlier](#migrating-from-62-and-earlier)
- [Common](#common)
  - [Create the form launcher](#create-the-form-launcher)
  - [App configurations](#app-configurations)
  - [Configuration values](#configuration-values)
  - [Present the form](#present-the-form)
  - [Receive the form result](#receive-the-form-result)
  - [Prefilled entries](#prefilled-entries)
  - [Errors](#errors)
  - [Clear data](#clear-data)
  - [Branding](#branding)
  - [Multi-Language](#multi-language)
- [Userless](#userless)
  - [Userless API](#userless-api)
  - [Userless integration steps](#userless-integration-steps)
  - [Userless errors](#userless-errors)
- [User-based](#user-based)
  - [User-based API](#user-based-api)
  - [Result format](#result-format)
  - [User-based integration steps](#user-based-integration-steps)
  - [Other calls](#other-calls)
  - [Working offline](#working-offline)
  - [User-based error codes](#user-based-error-codes)

## Introduction

Welcome to the GoCanvas Mobile SDK for iOS! The SDK lets you bring the power of GoCanvas forms into your own mobile app, so your users can fill out forms, capture photos, signatures and other media, and complete submissions without leaving your application.

The SDK can be used in two modes:

- **[Userless](#userless)** - your app provides the form JSON (plus optional reference and prefilled data) and receives the submission back. No GoCanvas user is involved.

  Use Userless mode when you create and maintain the forms you display to your users, or when you fetch the form definitions yourself using the GoCanvas API. Your app is responsible for storing and processing the submissions how you see fit.

- **[User-based](#user-based)** - the SDK works on behalf of a GoCanvas user: it syncs the user's forms, reference data, dispatches and handoffs, and uploads their submissions.

  Use User-based mode when your customers manage their own forms on the GoCanvas website. The SDK downloads and manages everything the user needs to access their assigned forms, and pushes the resulting submissions up to GoCanvas for you.

Both modes share the setup described in [Common](#common).

## Installation

Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding GCSdk as a dependency is as easy as adding it to the dependencies value of your Package.swift or the Package list in Xcode.
```
dependencies: [
    .package(url: "https://github.com/gocanvas/mobile_sdk_ios.git", .upToNextMajor(from: "6.3.0"))
]
```

### Add GCSdk build phase

1. Open **Build phase** tab for your application target, choose the + button (at the top of the pane).
2. Choose **New Run Script Phase**.
3. Add below into the new run script editor:
```
${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/GCSdk.framework/setup
```

### Update build settings

Go to **Build Settings** tab and search for **ENABLE_USER_SCRIPT_SANDBOXING** property. Set this property to **NO**. This is needed in order for the setup script from above to run successfully.

## Migrating from 6.2 and earlier

Existing integrations keep working in [Userless](#userless) mode: `GoCanvasFormLauncher`, `addConfigValue` and `formFlowController` are unchanged. The breaking changes are the format of the JSON passed to the `completion` closure and the error codes and messages, see [Error changes](#error-changes).

### The response is now wrapped in `error` and `data`

Up to 6.2, the `completion` closure received the submission itself. Starting with 6.3, it receives a JSON with an `error` and a `data` property, and the submission that was previously returned is now in the `data` property.

Before (6.2 and earlier):

```json
{
  "guid": "F4C7A1D9-8B1E-4D7F-9D5C-2D9E6B4E5A8F",
  "last_sheet_id": 12345,
  "status": "closed",
  "form": { "id": 4639578, "version": "1" },
  "responses": [ ... ]
}
```

After (6.3):

```json
{
  "error": null,
  "data": {
    "guid": "F4C7A1D9-8B1E-4D7F-9D5C-2D9E6B4E5A8F",
    "last_sheet_id": 12345,
    "status": "closed",
    "form": { "id": 4639578, "version": "1" },
    "responses": [ ... ],
    ...
  }
}
```

The content of `data` has the same properties as the 6.2 response, plus a few submission header properties that can be ignored in Userless mode, see [Read the response](#step-5-read-the-response). The only changed value is `displayed` in `responses`, which is now a boolean (`true` / `false`) instead of the string `" true"` / `" false"`.

### What to change

1. Read the submission from the `data` property instead of the root of the JSON. New in 6.3, the `completion` is also called when the user discards the form, with `data` set to `null`:

```swift
let controller = try await formLauncher.formFlowController(config: formConfig, messagingDelegate: self) { jsonResponse in
    // 6.2: let submission = try? JSONSerialization.jsonObject(with: Data(jsonResponse.utf8)) as? [String: Any]
    let envelope = try? JSONSerialization.jsonObject(with: Data(jsonResponse.utf8)) as? [String: Any]
    guard let submission = envelope?["data"] as? [String: Any] else { return } // discarded, nothing to read
    let status = submission["status"] as? String
    let responses = submission["responses"] as? [[String: Any]]
}
```

2. When you store an `open` response to [resume it later](#prefill-with-partially-response), store and pass back only the `data` object, not the whole JSON received by the `completion`. If the whole JSON is passed as `prefilledDataJson`, it is ignored and the form opens without the saved values.

```swift
if submission["status"] as? String == "open",
   let data = try? JSONSerialization.data(withJSONObject: submission) {
    savedResponse = String(decoding: data, as: UTF8.self) // later passed as prefilledDataJson
}
```

3. Keep handling the form flow errors with `FormLauncherError` and `SDKLicenseError`. In Userless mode, `error` is always `null`: when the form cannot be displayed, `formFlowController` still throws, see [Userless errors](#userless-errors). If you read the error codes or messages, see [Error changes](#error-changes).

### Error changes

Some error codes and messages have changed. If you only switch on the `FormLauncherError` and `SDKLicenseError` cases, the only change is the new `userModeConflictError` case.

| Error | Code in 6.2 | Code in 6.3 |
|---|---|---|
| `FormLauncherError.missingCameraConfiguration` | 90003 | 90100 |
| `FormLauncherError.referenceDataError` | 90004 | 90003 |
| `FormLauncherError.formRetiredError` | 90005 | 90013 |
| `FormLauncherError.userModeConflictError` | - | 90017 (new) |
| `SDKLicenseError.invalidLicenseKey` | 90100 | 90004 |
| `SDKLicenseError.invalidBundleId` | 90101 | 90005 |

Changed messages:

- `referenceDataError` - "Reference data is incomplete" is now "Unable to show form. Reference data was not set."
- `formRetiredError` - "Form Retired" is now "This form has been retired and can no longer be used."
- `invalidLicenseKey` - "contact you account manager" is now "contact your account manager"


## Common

This section describes what both modes share. The SDK can be accessed by importing the GCSdk:

```swift
import GCSdk
```

### Create the form launcher

All the SDK methods are called on a `GoCanvasFormLauncher` instance, created with the license key:

```swift
public class GoCanvasFormLauncher {
    public init(config: GCSdkConfig)
}

public struct GCSdkConfig {
    public init(licenseKey: String)
}
```

| Parameter | Description |
|---|---|
| `licenseKey` | the license key provided by GoCanvas for your application. Not needed in [User-based](#user-based) mode, where a blank string (`""`) can be passed |

```swift
let formLauncher = GoCanvasFormLauncher(config: GCSdkConfig(licenseKey: "<your_license_key>"))
```

Keep the launcher for as long as you use the SDK. The license key is validated when a [Userless](#userless) form is shown; an invalid key is thrown as an [`SDKLicenseError`](#userless-errors).

> **Note:** The license key is only used in Userless mode. In [User-based](#user-based) mode it is not needed, so you can pass a blank string:
>
> ```swift
> let formLauncher = GoCanvasFormLauncher(config: GCSdkConfig(licenseKey: ""))
> ```

### App configurations

The application is required to populate their info.plist with the following fields:

|Key | Recommended value |
| -------------------------|-------------------------|
|NSBluetoothAlwaysUsageDescription|Bluetooth is used to capture barcodes|
|NSCameraUsageDescription|Our app uses the camera to capture photos that are uploaded as part of your submission.|
|NSContactsUsageDescription|Contacts are used when emailing a submission.|
|NSLocationWhenInUseUsageDescription|Allow location usage so when a GPS control is clicked the geolocation data can be saved and submitted.|
|NSLocationAlwaysUsageDescription|Allow location usage so when a GPS control is clicked the geolocation data can be saved and submitted.|
|NSMicrophoneUsageDescription|Microphone is used to capture videos during a submission.|
|NSPhotoLibraryUsageDescription|Photo Library is used to obtain photos during a submission.|
|NSLocationTemporaryUsageDescriptionDictionary||
|- WantAccuracy|Your precise location will be used in this submission.|

### Configuration values

```swift
public func addConfigValue(key: String, value: Any)
```

| Parameter | Description |
|---|---|
| `key` | one of the configuration keys below |
| `value` | the value for that key, of the type listed below |

Returns nothing. Call it right after creating the launcher and before showing a form (for `MOBILE_DOMAIN`, before the first `sync`).

| Key | Value type | Default | Used by |
|---|---|---|---|
| `MOBILE_INTERFACE_THEME` | `UIUserInterfaceStyle` | `.light` | both modes, see [Light & Dark mode](#light--dark-mode) |
| `MOBILE_LANGUAGE` | `Locale.LanguageCode` | the device language, with `English (US)` fallback | both modes, see [Multi-Language](#multi-language) |
| `MOBILE_DOMAIN` | `String`, the GoCanvas server host (e.g. `"www.gocanvas.com"`) | the GoCanvas production server | User-based, see [Set the server](#step-2-set-the-server-optional) |

### Present the form

In both modes the SDK returns a `UIViewController` that runs the form flow, and your application presents it:

- Userless: [`formFlowController`](#step-4-get-and-present-the-form-controller)
- User-based: [`showForm` / `showSubmission`](#step-7-show-a-form-or-a-submission)

These methods are `async throws` and must be called on the main thread. When the form cannot be displayed they throw instead of returning a controller (see [Errors](#errors)). In User-based mode, `showForm` / `showSubmission` also call the `completion` with the error before throwing, see [Receive the form result](#receive-the-form-result).

```swift
do {
    let controller = try await formLauncher.formFlowController(config: formConfig, messagingDelegate: self) { jsonResponse in
        // see "Receive the form result"
    }
    present(controller, animated: true)
} catch {
    // nothing to present
}
```

### Receive the form result

The result is delivered through the `completion` closure passed when retrieving the controller. It is called when the form flow ends: when the user taps on *_Submit_* on the last page of the flow, elects to "Save and Close" the submission, discards the form or, in User-based mode, rejects a handoff. The closure is called on the main thread, after the SDK screen has been dismissed, so you can present another screen from it.

The closure receives a `String` containing a JSON with an `error` and a `data` property. The content of `data` depends on the mode:

- Userless: the full submission, including the entries' values, see [Read the response](#step-5-read-the-response)
- User-based: only the submission header, see [Read the result](#step-8-read-the-result)

When the user discards the form without saving it, the closure receives `{ "error": null, "data": null }`: nothing was saved, so there is nothing to read.

When the user rejects a handoff, `data` contains the submission header with `rejected` set to `true`.

In User-based mode, when `showForm` / `showSubmission` cannot display the form, the closure is called right away with the error (`{ "error": { "code": ..., "message": ... }, "data": {} }`) and the call also throws. Nothing is presented, so handle the error in only one place.

### Prefilled entries
<a id="prefilled-entries-scope"></a>

Both modes accept an optional JSON string that prefills the form's entries (`prefilledDataJson` in Userless, `prefilledEntries` in User-based). The following formats are supported:

1. Prefill all entries based on labels:
<a id="prefill-by-label"></a>

```json
{
  "responses": [
    {
      "value": "Example Value",
      "label": "Example Label"
    }
  ]
}
```

2. Prefill only specific entries based on form's entry id (Userless only). When `entry_id` is present, `label` is optional and ignored:
```json
{
  "responses": [
    {
      "entry_id": 123456,
      "value": "Example Value",
      "label": "Example Label", // Label is Optional
      // Required for List loop
      "id": 391647,
      "multi_key": "Example Multi Key"
    }
  ]
}
```

3. Prefill with Partially Response (Userless only): resumes a response previously returned with status `open`. It uses the same `responses` as format 2; with `"status": "open"`, the form also opens on the `last_sheet_id` sheet
<a id="prefill-with-partially-response"></a>

```json
{
  "guid": "12345-abcd",
  "last_sheet_id": 12345,
  "status": "open",
  "form": {
    "id": 6789,
    "version": "1"
  },
  "responses": [
    {
      "entry_id": 12345,
      "guid": "55EB..",
      "displayed": true,
      "multi_key": "Multi Key Example Value",
      "key_id": 789789,
      "multi_key_id": 345345,
      "value": "Example Value",
      "label": "Example Label"
    }
  ]
}  
```

### Errors

The two modes report errors differently:

- Userless: `formFlowController` throws a `FormLauncherError` or an `SDKLicenseError`, see [Userless errors](#userless-errors)
- User-based: the calls return the error in the `error` property of the returned JSON, see [Result format](#result-format). When `showForm` / `showSubmission` cannot display the form, they also throw an `NSError` with the same error, see [Show a form or a submission](#step-7-show-a-form-or-a-submission). The error codes are listed in [User-based error codes](#user-based-error-codes)

### Clear data

```swift
public func clearData()
```

Takes no parameters and returns nothing. Deletes all the data the SDK has stored on the device. It can be used in both modes and must not be called on the main thread.

### Branding

#### Colors

The color system that can be used to create a color scheme that reflects your brand or style.

|Color Name | Default (Light) | Default (Dark) |
| -------------------------|--------------|--------------|
| gc_sdk_color_primary                  | ![#0e51c4](https://placehold.co/15x15/0e51c4/0e51c4.png) #0e51c4 | ![#039de7](https://placehold.co/15x15/039de7/039de7.png) #039de7 |
| gc_sdk_color_secondary                | ![#ecf1fa](https://placehold.co/15x15/ecf1fa/ecf1fa.png) #ecf1fa | ![#000d12](https://placehold.co/15x15/000d12/000d12.png) #000d12 |
| gc_sdk_color_background               | ![#f5f6f6](https://placehold.co/15x15/f5f6f6/f5f6f6.png) #f5f6f6 | ![#151b1e](https://placehold.co/15x15/151b1e/151b1e.png) #151b1e |
| gc_sdk_color_secondary_container      | ![#ffffff](https://placehold.co/15x15/ffffff/ffffff.png) #ffffff | ![#0a1214](https://placehold.co/15x15/0a1214/0a1214.png) #0a1214 |
| gc_sdk_color_secondary_container_low  | ![#f5f8fd](https://placehold.co/15x15/f5f8fd/f5f8fd.png) #f5f8fd | ![#000609](https://placehold.co/15x15/000609/000609.png) #000609 |
| gc_sdk_color_secondary_container_high | ![#fafafa](https://placehold.co/15x15/fafafa/fafafa.png) #fafafa | ![#10171a](https://placehold.co/15x15/10171a/10171a.png) #10171a |
| gc_sdk_color_background_progress      | ![#d8d9da](https://placehold.co/15x15/d8d9da/d8d9da.png) #d8d9da | ![#32383a](https://placehold.co/15x15/32383a/32383a.png) #32383a |
| gc_sdk_color_progress                 | ![#0e51c4](https://placehold.co/15x15/0e51c4/0e51c4.png) #0e51c4 | ![#039de7](https://placehold.co/15x15/039de7/039de7.png) #039de7 |
| gc_sdk_color_error                    | ![#c40e51](https://placehold.co/15x15/c40e51/c40e51.png) #c40e51 | ![#e63a79](https://placehold.co/15x15/e63a79/e63a79.png) #e63a79 |
 
By overriding these color attributes, you can easily change the style of the customizable components used by the sdk.

#### Light & Dark mode

**Applying your own colors:**

1. Enable the theme mode with the SDK API (default is set to `LIGHT`)

Call the following method after SDK config initialization:

```swift 
formLauncher.addConfigValue(key: "MOBILE_INTERFACE_THEME", value: UIUserInterfaceStyle.dark)
```

2. In order to use your color as the theme for the form flow, a `Color Set` must be added to any `xcasset` available in your target with the following names:
- `gc_sdk_color_primary`
- `gc_sdk_color_secondary`
- `gc_sdk_color_secondary_container`
- `gc_sdk_color_secondary_container_low`
- `gc_sdk_color_secondary_container_high`
- `gc_sdk_color_background_progress`
- `gc_sdk_color_background`
- `gc_sdk_color_progress`
- `gc_sdk_color_error`

### Multi-Language

Supported languages:

| Language                | Language key    |
|-------------------------|-----------------|
| English (US)            | en              |
| English (UK)            | en-GB           |
| Chinese (Simplified)    | zh-CN           |
| Chinese (Traditional)   | zh-TW           |
| Czech                   | cs-CZ           |
| Danish                  | da-DK           |
| Dutch                   | nl-NL           |
| Finnish                 | fi-FI           |
| French                  | fr-FR           |
| French (Canada)         | fr-CA           |
| German                  | de-DE           |
| Hindi                   | hi-IN           |
| Hungarian               | hu-HU           |
| Lithuanian              | lt-LT           |
| Malay                   | ms-MY           |
| Norwegian (Bokmål)      | nb-NO           |
| Polish                  | pl-PL           |
| Portuguese              | pt-PT           |
| Slovak                  | sk-SK           |
| Spanish                 | es-ES           |
| Spanish (Latin America) | es-419          |
| Swedish                 | sv-SE           |
| Turkish                 | tr-TR           |

Default language: the device language when it is supported, otherwise `English (US)`

Configuration usage:
```swift
// use a language key exactly as listed in the table above, e.g. "es-ES", "fr-CA", "zh-TW"
let languageCode = Locale.LanguageCode("es-ES")
formLauncher.addConfigValue(key: "MOBILE_LANGUAGE", value: languageCode)
```

#### Localizing Privacy Permission Strings

If you want to translate also the privacy usage descriptions defined in your `Info.plist` (e.g., Camera, Location, Microphone access), you need to add the specific keys to your `InfoPlist.strings` file for each supported language. Needed privacy permissions for GoCanvas SDK are listed in [App configurations](#app-configurations) section.

#### Strings 

You can update the `Submit` button text by overriding the key ***submit_button_title*** into your `Localizable.xcstrings` file.

## Userless

In Userless mode your application provides the form definition (plus optional reference data and prefilled entries) and receives the completed submission back, including the entries' values. The SDK does not keep the submission once it has been returned: storing and uploading it is up to your application.

### Userless API

```swift
public class GoCanvasFormLauncher {
    //... init, addConfigValue and clearData, see "Common"

    /// Returns the controller that runs the form flow.
    /// - Parameters:
    ///   - config: the form definition, plus optional reference data and prefilled entries
    ///   - messagingDelegate: receives the SDK's requests to the app, such as resuming a leftover response
    ///   - completion: called when the form flow ends with a JSON with an `error` and a `data` property,
    ///     where `data` contains the full submission, including the entries' values.
    ///     See [Read the response](#step-5-read-the-response).
    /// - Returns: the controller to present
    /// - Throws: a `FormLauncherError` or an `SDKLicenseError`, see [Userless errors](#userless-errors)
    @MainActor
    public func formFlowController(config: GCSdkFormConfig,
                                   messagingDelegate: CanvasSdkMessagingDelegate,
                                   completion: @escaping (String) -> ()) async throws -> UIViewController
}
```

### Userless integration steps

1. [Create the form launcher](#create-the-form-launcher) (see Common)
2. [Implement the messaging delegate](#step-2-implement-the-messaging-delegate)
3. [Get the form definition](#step-3-get-the-form-definition)
4. [Get and present the form controller](#step-4-get-and-present-the-form-controller)
5. [Read the response](#step-5-read-the-response)

```swift
let formLauncher = GoCanvasFormLauncher(config: GCSdkConfig(licenseKey: "<your_license_key>"))

do {
    let formConfig = GCSdkFormConfig(jsonInput: formJson,
                                     referenceDataJson: referenceDataJson,
                                     prefilledDataJson: prefilledDataJson)
    let controller = try await formLauncher.formFlowController(config: formConfig, messagingDelegate: self) { jsonResponse in
        // { "error": null, "data": { "guid": ..., "status": ..., "responses": [...] } }
    }
    present(controller, animated: true)
} catch let error as FormLauncherError {
    // error.message
} catch let error as SDKLicenseError {
    // error.message
} catch {
    // any other error
}
```

#### Step 2: Implement the messaging delegate

Through the `CanvasSdkMessagingDelegate`, the SDK will request a specific action from the parent app.

The current use case for this is when a form has been previously completed partially, and we are requesting the application to tell us if they want to discard the previous action or if they want to continue. Calling the action handler on any of the `CanvasSdkMessagingAction` objects offered in the delegate will decide the behavior of the form flow for the current session.

```swift
public struct CanvasSdkMessagingAction {
    public let actionTitle: String
    public let actionHandler: () -> Void
}

public protocol CanvasSdkMessagingDelegate {
    func showResumeMessage(withTitle: String,
                           body: String,
                           discardAction: CanvasSdkMessagingAction,
                           continueAction: CanvasSdkMessagingAction,
                           userInterfaceStyle: UIUserInterfaceStyle)
}
```

##### App crash or unexpected form closing

If the app crashes or closes unexpectedly, upon launching the SDK for a form the SDK will check for a "leftover" response from a previous unexpected close. If a "leftover" response exists for the form, the SDK asks your application through `showResumeMessage` whether the user wishes to continue the "leftover" response or discard it and continue.

#### Step 3: Get the form definition

The SDK accepts the `format=sync` form definition obtained through the GoCanvas API:

Example: `https://www.gocanvas.com/api/v3/forms/123456?format=sync`

When the form uses reference data, fetch it through the GoCanvas API as well and pass it together with the form (see the next step); otherwise the form fails with `referenceDataError`.

#### Step 4: Get and present the form controller

```swift
@MainActor
public func formFlowController(config: GCSdkFormConfig,
                               messagingDelegate: CanvasSdkMessagingDelegate,
                               completion: @escaping (String) -> ()) async throws -> UIViewController

public struct GCSdkFormConfig {
    public init(jsonInput: String,
                referenceDataJson: String? = nil,
                prefilledDataJson: String? = nil)
}
```

| Parameter | Description |
|---|---|
| `config.jsonInput` | the form definition from [Step 3](#step-3-get-the-form-definition), as a JSON string |
| `config.referenceDataJson` | optional, the form's reference data as a JSON string |
| `config.prefilledDataJson` | optional, the prefilled entries, see [Prefilled entries](#prefilled-entries) |
| `messagingDelegate` | the delegate from [Step 2](#step-2-implement-the-messaging-delegate) |
| `completion` | receives the result when the form flow ends, see [Step 5](#step-5-read-the-response) |

Returns the controller to present, see [Present the form](#present-the-form). When the form cannot be displayed, it throws one of the [Userless errors](#userless-errors).

#### Step 5: Read the response

The `completion` closure receives a JSON with an `error` and a `data` property, where `data` contains the submission:

```json
{
  "error": null,
  "data": {
    "guid": "F4C7A1D9-8B1E-4D7F-9D5C-2D9E6B4E5A8F",
    "name": "*** 09/24/26 10:15:02",
    "status": "closed",
    "last_saved_at": 1727172902,
    "dispatch_id": null,
    "deletable": true,
    "pendingUpload": true,
    "rejected": false,
    "last_sheet_id": 12345,
    "form": {
      "id": 4639578,
      "version": "1"
    },
    "responses": [
      { "entry_id": 543728076, "guid": "A1B2C3D4-...", "displayed": true, "value": "api.user@example.com", "label": "Email" },
      { "entry_id": 543728079, "guid": "E5F6A7B8-...", "displayed": true, "multi_key": "Priority", "value": "High", "label": "Level" }
    ]
  }
}
```

| Property | Description |
|---|---|
| `guid` | the submission's unique id |
| `status` | `closed` when the user tapped "Submit", or `open` when the user elected to "Save and Close" |
| `last_sheet_id` | the last screen the user visited |
| `form` | the `id` and `version` of the form |
| `responses` | one item per entry, with its `entry_id`, entry `guid`, `label`, `value` and whether it was `displayed`. Entries inside list loops also have a `multi_key` |

The remaining properties (`name`, `last_saved_at`, `dispatch_id`, `deletable`, `pendingUpload`, `rejected`) are the submission header shared with the [User-based submissions](#step-6-get-the-forms-and-submissions). In Userless mode the SDK neither stores nor uploads the submission, so they can be ignored.

An `open` response can be resumed later by passing it back as [prefilled entries](#prefill-with-partially-response).

##### Reading Media files

Images, Drawings, Signatures, Videos, Attachments

As in 6.2, the `value` of a media entry contains the local path(s) of its file(s). The files are saved in the `gocanvassdk` folder of your app's `Documents` directory, which [`clearData`](#clear-data) deletes.

1. Entry response with single media file

- the `value` property contains the local path to the file as a `String`

```json
{
  ..
  "value": "path_to_image_1",
  "label": "Camera Photo"
}
```

2. Entry response with multiple media files

- the `value` property contains a single `String` that concatenates all the paths to the files, separated by `"\r\n"`

```json
{
  ..
  "value": "path_to_image_1\r\npath_to_image_2\r\npath_to_image_3",
  "label": "Multi Photo"
}
```

### Userless errors

`formFlowController` throws a `FormLauncherError` when the form cannot be displayed:

- `invalidJson` - when the `jsonInput` parameter cannot be parsed to `Form`
- `missingData` - when the `Form` has no sections, sheets or entries
- `resumeFormFailed` - when the `Response` cannot be restored after partially form saving
- `missingCameraConfiguration` - when the app does not contain the required camera details in the info.plist
- `referenceDataError` - when a form expects reference data, but no correct reference data has been provided in the form config
- `formRetiredError` - when the form has been retired
- `userModeConflictError` - when the form, or the reference data it uses, is already synced for the user, see [User-based](#user-based)
- `unknown` - when any other type of error has occurred

Each error has an associated `message` that can be interrogated:

```swift
public enum FormLauncherError : Error {
    case invalidJson(userInfo: [String: Any], description: String)
    case missingData(description: String)
    case resumeFormFailed(description: String)
    case missingCameraConfiguration(description: String)
    case referenceDataError(description: String)
    case formRetiredError(description: String)
    case userModeConflictError(description: String, debugMessage: String)
    case unknown(error: NSError)

    public var message: String { get }
}
```

For `invalidJson` error, there's a dictionary with the JSON parsing error attached, as defined by the platform's API. For `userModeConflictError`, `debugMessage` holds developer-facing details, for logging only. For `unknown` error, there's an `NSError` object attached, defined by the platform.

The `message` property returns the following error messages:

- `invalidJson` - "Unable to parse form definition."
- `missingData` - "Form definition is invalid."
- `resumeFormFailed` - "Unable to resume response."
- `missingCameraConfiguration` - "Missing camera configuration in the main app."
- `referenceDataError` - "Unable to show form. Reference data was not set."
- `formRetiredError` - "This form has been retired and can no longer be used."
- `userModeConflictError` - "Unable to show form."
- `unknown` - Returns the `description` of the NSError object

When the license key is not valid, `formFlowController` throws an `SDKLicenseError`:

- `invalidLicenseKey` - when the license key provided is not valid
- `invalidBundleId` - when the license key provided is not valid for the app's bundle identifier
- `unknown` - when any other license error has occurred

```swift
public enum SDKLicenseError: Error {
    case invalidLicenseKey(description: String)
    case invalidBundleId(description: String)
    case unknown(error: NSError)

    public var message: String { get }
}
```

The `message` property returns the following error messages:

- `invalidLicenseKey` - "License key is invalid, please contact your account manager for assistance."
- `invalidBundleId` - "Invalid package identifier, please contact your account manager for assistance."
- `unknown` - Returns the `description` of the NSError object

## User-based

Starting with 6.3.0, the SDK can work on behalf of a GoCanvas user. Using the user's OAuth token, the SDK downloads the forms, reference data, dispatches and handoffs assigned to that user, stores them on the device, and uploads the submissions the user completes. Your application no longer needs to fetch form definitions or reference data itself, and the entries' values are never returned to it.

### User-based API

```swift
public class GoCanvasFormLauncher {
    //... init, addConfigValue and clearData, see "Common"

    /// Registers a provider the SDK calls to obtain a new token when the stored one has expired.
    /// - Parameter tokenProvider: returns the token JSON of the synced user, in the same format passed to `sync`.
    ///   It is called off the main thread and must not call the other SDK methods. Pass `nil` to unregister it.
    ///   See [Register a token provider](#step-4-register-a-token-provider-optional).
    public func setTokenProvider(_ tokenProvider: (() -> String)?)

    /// Uploads the completed submissions, then downloads the user's forms, reference data,
    /// dispatches and handoffs. The first successful sync stores the user on the device.
    /// - Parameters:
    ///   - username: the user's GoCanvas username (email)
    ///   - token: the user's OAuth token JSON, see [Obtain the user's token](#step-3-obtain-the-users-token)
    ///   - uploadOnly: when `true`, only uploads the completed submissions
    /// - Returns: a JSON with an `error` and a `data` property. On success `data` contains the counts of
    ///   `forms_added`, `forms_removed`, `forms_retired`, `dispatches_added` and `dispatches_removed`
    ///   (empty when `uploadOnly` is `true`). See [Sync](#step-5-sync).
    ///
    /// NOTE: this must not be run on the main thread
    public func sync(username: String, token: String, uploadOnly: Bool = false) -> String

    /// Returns the forms stored on the device, each with its submissions.
    /// - Parameter username: the synced user's username
    /// - Returns: a JSON with an `error` and a `data` property. On success `data` contains the `forms`
    ///   array, and each form contains its `submissions` array.
    ///   See [Get the forms and submissions](#step-6-get-the-forms-and-submissions).
    ///
    /// NOTE: this must not be run on the main thread
    public func getFormsAndSubmissions(username: String) -> String

    /// Starts a new submission for a form stored on the device by `sync`.
    /// - Parameters:
    ///   - username: the synced user's username
    ///   - formId: the `id` of the form, as returned by `getFormsAndSubmissions`
    ///   - prefilledEntries: the prefilled entries in JSON string format, see
    ///     [Prefill all entries based on labels](#prefill-by-label). The `label` is mandatory.
    ///   - completion: called when the form flow ends with a JSON with an `error` and a `data` property,
    ///     where `data` contains only the submission header. See [Read the result](#step-8-read-the-result).
    /// - Returns: the controller to present
    @MainActor
    public func showForm(username: String,
                         formId: Int64,
                         prefilledEntries: String? = nil,
                         completion: @escaping (String) -> ()) async throws -> UIViewController

    /// Opens a saved submission, dispatch or handoff stored on the device by `sync`.
    /// - Parameters:
    ///   - username: the synced user's username
    ///   - guid: the `guid` of the submission, as returned by `getFormsAndSubmissions`
    ///   - prefilledEntries: the prefilled entries in JSON string format, see
    ///     [Prefill all entries based on labels](#prefill-by-label). The `label` is mandatory.
    ///   - completion: called when the form flow ends with a JSON with an `error` and a `data` property,
    ///     where `data` contains only the submission header. See [Read the result](#step-8-read-the-result).
    /// - Returns: the controller to present
    @MainActor
    public func showSubmission(username: String,
                               guid: String,
                               prefilledEntries: String? = nil,
                               completion: @escaping (String) -> ()) async throws -> UIViewController

    /// Deletes a saved submission from the device.
    /// - Parameters:
    ///   - username: the synced user's username
    ///   - guid: the `guid` of the submission, as returned by `getFormsAndSubmissions`
    /// - Returns: a JSON with an `error` and a `data` property. On success `data` contains the deleted
    ///   submission. Dispatches, handoffs and completed submissions cannot be deleted and return a
    ///   `submissionCannotBeDeleted` error.
    ///
    /// NOTE: this must not be run on the main thread
    public func deleteSubmission(username: String, guid: String) -> String

    /// Returns `true` when any submission on the device has `pendingUpload: true`, i.e. it will be
    /// uploaded (or finish uploading) on the next `sync`.
    ///
    /// NOTE: this must not be run on the main thread
    public func hasPendingSubmissions() -> Bool
}
```

`sync`, `getFormsAndSubmissions`, `deleteSubmission` and `hasPendingSubmissions` are synchronous and access the network or the local database, so they must be called off the main thread. `showForm` and `showSubmission` must be called on the main thread, like `formFlowController`.

### Result format

Except for `hasPendingSubmissions`, all user-based calls return (or deliver through their completion) a `String` containing a JSON with an `error` and a `data` property.

On success, `error` is `null` and `data` contains the result of the call:

```json
{ "error": null, "data": { } }
```

On failure, `error` contains the error `code`, the user-facing `message` (see [User-based error codes](#user-based-error-codes)) and, when available, a `debug_message`:

```json
{ "error": { "code": 90010, "message": "The provided token is not valid for the specified user.", "debug_message": "Token user 'john.doe@example.com' does not match 'jane.doe@example.com'" }, "data": {} }
```

The `debug_message` holds developer-facing details about what failed. It is not translated and its content may change, so use it for logging only: don't show it to the user or parse it.

### User-based integration steps

1. [Create the form launcher](#create-the-form-launcher) (see Common). The license key is not needed, so a blank string can be passed
2. [Set the server](#step-2-set-the-server-optional) (optional)
3. [Obtain the user's token](#step-3-obtain-the-users-token)
4. [Register a token provider](#step-4-register-a-token-provider-optional) (optional)
5. [Sync](#step-5-sync)
6. [Get the forms and submissions](#step-6-get-the-forms-and-submissions)
7. [Show a form or a submission](#step-7-show-a-form-or-a-submission)
8. [Read the result](#step-8-read-the-result)
9. [Sync again](#step-9-sync-again) to upload the completed submissions and receive the latest changes

```swift
let username = "user@company.com"
let formLauncher = GoCanvasFormLauncher(config: GCSdkConfig(licenseKey: "")) // the license key is not needed in User-based mode
formLauncher.setTokenProvider { myAuthService.currentTokenJson() }

// sync and getFormsAndSubmissions must not run on the main thread
let syncResult = await Task.detached { formLauncher.sync(username: username, token: tokenJson) }.value
let formsAndSubmissions = await Task.detached { formLauncher.getFormsAndSubmissions(username: username) }.value

// list the forms and submissions, then open one:
do {
    let controller = try await formLauncher.showForm(username: username, formId: 123456) { envelope in
        // { "error": null, "data": { "guid": ..., "status": ..., "pendingUpload": ... } }
    }
    present(controller, animated: true)
} catch {
    // nothing to present, the error was also delivered to the completion
}
```

#### Step 2: Set the server (optional)

The SDK connects to the GoCanvas production server by default. To set the GoCanvas server explicitly, add the `MOBILE_DOMAIN` config value right after creating the launcher and before the first `sync`:

```swift
formLauncher.addConfigValue(key: "MOBILE_DOMAIN", value: "www.gocanvas.com")
```

The user's OAuth token must be issued by the same server.

#### Step 3: Obtain the user's token

Obtain an OAuth token for the user from GoCanvas. The token is the JSON returned by the GoCanvas OAuth endpoint and must contain an `access_token` issued for the user's `username`:

```json
{ "access_token": "<access_token>", "expires_in": 7200, "created_at": 1727172902 }
```

Pass the token to `sync` as you received it. The SDK uses `created_at` and `expires_in` to detect that the token has expired; a token without both properties is never treated as expired, so the [token provider](#step-4-register-a-token-provider-optional) is only called when the server rejects a request as unauthorized.

#### Step 4: Register a token provider (optional)

```swift
public func setTokenProvider(_ tokenProvider: (() -> String)?)
```

| Parameter | Description |
|---|---|
| `tokenProvider` | returns a valid token JSON for the synced user, in the same format passed to `sync`; `nil` unregisters it |

Returns nothing. By default, when the stored token expires, the SDK calls return a `networkError`. To let the SDK refresh the token by itself, register a token provider:

```swift
formLauncher.setTokenProvider {
    // return a valid token JSON for the synced user
    return myAuthService.currentTokenJson()
}
```

The provider is called when the stored token has expired, and when the server rejects a request as unauthorized, in which case the request is retried once with the new token. Please note:

- the provider is called off the main thread and blocks the calling thread until it returns, so it must not wait on the main thread
- it must not call the other SDK methods, but it may call `setTokenProvider(nil)` to unregister itself (e.g. when the user signs out)
- a token issued for a different user is not used
- the provider is shared by all launcher instances, the most recent registration wins, and it is kept after `clearData`

#### Step 5: Sync

```swift
public func sync(username: String, token: String, uploadOnly: Bool = false) -> String
```

| Parameter | Description |
|---|---|
| `username` | the user's GoCanvas username (email) |
| `token` | the user's token JSON from [Step 3](#step-3-obtain-the-users-token) |
| `uploadOnly` | when `true`, only uploads the completed submissions, which makes the sync faster when you don't need to refresh the forms and submissions list |

`sync` uploads the completed submissions, then downloads the user's forms, reference data, dispatches and handoffs. It must not be called on the main thread.

- The first successful `sync` stores the user on the device. All the other calls must use the same `username`.
- Only one user can be synced at a time. To switch to a different user, [`clearData`](#clear-data) must be called first.
- When the first `sync` of a user fails, no user is stored: the user-based calls return `noSyncedUser` until a `sync` succeeds.
- A failed `sync` does not remove an already synced user.
- The first sync of a user downloads every assigned form, which can take a while for a large account. Later syncs only download what has changed and are much faster. The call returns only when the whole sync has finished, so we recommend showing a progress UI while it runs.
- Only one sync can run at a time; calling `sync` while another sync is running returns a `syncInProgress` error.

Returns a JSON (see [Result format](#result-format)) where, on success, `data` contains a summary of the changes:

```json
{
  "error": null,
  "data": {
    "forms_added": 2,
    "forms_removed": 0,
    "forms_retired": 1,
    "dispatches_added": 1,
    "dispatches_removed": 0
  }
}
```

When a form has been retired or is no longer assigned to the user but still has submissions on the device, it is kept as `retired`: new submissions can no longer be created, but existing submissions can be opened and completed.

With `uploadOnly: true`, `data` is empty. When the sync fails, `error` is set and `data` contains the counts collected before the failure.

When a different user is already synced on the device, `sync` returns a `differentUser` error and `data` contains that user, so you can ask whether to clear their data first:

```json
{
  "error": { "code": 90011, "message": "A different user is already synced. Clear data before syncing a new user." },
  "data": { "name": "Jane Doe", "email": "jane@company.com" }
}
```

Possible errors: `invalidToken`, `tokenUserMismatch`, `differentUser`, `networkError`, `syncFailed`, `syncInProgress`.

#### Step 6: Get the forms and submissions

```swift
public func getFormsAndSubmissions(username: String) -> String
```

| Parameter | Description |
|---|---|
| `username` | the synced user's username |

It must not be called on the main thread. Returns a JSON (see [Result format](#result-format)) where, on success, `data` contains the forms stored on the device, each with its submissions:

```json
{
  "error": null,
  "data": {
    "forms": [
      {
        "id": 123456,
        "type": "form",
        "name": "Site Inspection",
        "version": 3,
        "status": "published",
        "email_options": 2,
        "workflow_enabled": true,
        "image_path": "/path/to/formicons/img_987_1.png",
        "submissions": [
          {
            "guid": "0D1B5C2E-...",
            "name": "*** 09/24/26 10:15:02",
            "status": "open",
            "last_saved_at": 1727172902,
            "dispatch_id": null,
            "deletable": true,
            "pendingUpload": false,
            "rejected": false
          }
        ]
      }
    ]
  }
}
```

Use the form `id` to start a new submission with `showForm`, and the submission `guid` to open it with `showSubmission` or delete it with `deleteSubmission`.

The form properties:

| Property | Description |
|---|---|
| `id` | the form id, passed to `showForm` |
| `type` | always `form` |
| `name` | the form's display name |
| `version` | the form version stored on the device |
| `status` | `published` or `retired`, see below |
| `email_options` | the form's email setting, as configured in GoCanvas |
| `workflow_enabled` | `true` when the form is part of a workflow (its submissions can be handed off) |
| `image_path` | the local path of the form's image |
| `submissions` | the form's submissions stored on the device, see below |

The form `status` can contain one of the following values:
1. `published` - new submissions can be started with `showForm`
2. `retired` - the form has been retired or is no longer assigned; new submissions can no longer be created, but existing submissions can be opened and completed

The submission `status` can contain one of the following values:
1. `open` - the submission can still be edited: the user has elected to "Save and Close" it, or it is a dispatch or handoff not submitted yet
2. `closed` - the user has submitted the submission; it can no longer be edited and is waiting to be uploaded, or its media files are still uploading

Once a submission and all its media files are uploaded, the submission is removed from the device and is no longer returned. If its media files do not finish uploading, it stays `closed` until a subsequent `sync` uploads them.

The submission properties:

| Property | Description |
|---|---|
| `guid` | the submission id, passed to `showSubmission` and `deleteSubmission` |
| `name` | the submission's display name. For a handoff, its name as received from GoCanvas, falling back to the submission name or number when it has none |
| `status` | `open` or `closed`, see above |
| `last_saved_at` | when the submission was last saved, in epoch seconds, or `null` |
| `dispatch_id` | the dispatch id when the submission is a dispatch, otherwise `null` |
| `deletable` | whether `deleteSubmission` can delete it (dispatches, handoffs and completed submissions cannot be deleted) |
| `pendingUpload` | `true` when the submission is `closed`, so it will be uploaded (or finish uploading) on the next `sync` |
| `rejected` | `true` when the submission is a handoff rejected back to the user; it then also contains the `rejector` and the `rejection_note` |

Possible errors: `noSyncedUser`, `invalidUser`.

#### Step 7: Show a form or a submission

```swift
@MainActor
public func showForm(username: String,
                     formId: Int64,
                     prefilledEntries: String? = nil,
                     completion: @escaping (String) -> ()) async throws -> UIViewController

@MainActor
public func showSubmission(username: String,
                           guid: String,
                           prefilledEntries: String? = nil,
                           completion: @escaping (String) -> ()) async throws -> UIViewController
```

- `showForm` - starts a new submission for the form with the specified `formId`
- `showSubmission` - opens the saved submission, dispatch or handoff with the specified `guid`. Only `open` submissions can be opened; a `closed` one returns a `submissionCompleted` error

| Parameter | Description |
|---|---|
| `username` | the synced user's username |
| `formId` | `showForm` only: the form `id`, as returned by `getFormsAndSubmissions` |
| `guid` | `showSubmission` only: the submission `guid`, as returned by `getFormsAndSubmissions` |
| `prefilledEntries` | optional, see [Prefill all entries based on labels](#prefill-by-label); the `label` is mandatory and must match the label of the form's entry |
| `completion` | receives the result when the form flow ends, see [Step 8](#step-8-read-the-result) |

Returns the controller to present, see [Present the form](#present-the-form). Both methods work with the data stored by `sync`, so you don't pass a form JSON or reference data.

Drawings on dispatches and handoffs are downloaded during `sync`, so they can be viewed immediately when opening the submission. Other media files are downloaded when the user taps on the field.

If the form or submission cannot be displayed, the method throws an `NSError` and the `completion` receives the same error. The `NSError` has the `"CanvasSdkErrorDomain"` domain, its `code` is the error code and its `localizedDescription` is the error message. Since both receive the same error, you can handle all the results in the `completion` and treat the thrown error only as "nothing to present":

```swift
do {
    let controller = try await formLauncher.showSubmission(username: username, guid: guid) { envelope in
        // handle the submission summary or the error
    }
    present(controller, animated: true)
} catch let error as NSError where error.domain == "CanvasSdkErrorDomain" {
    // already delivered to the completion, error.code contains the error code
}
```

The possible errors are:

- `noSyncedUser` - when no user has been synced yet
- `invalidUser` - when `username` does not match the synced user
- `invalidJson` - when the form is not found on the device
- `invalidSavedResponse` - when the submission is not found on the device
- `formRetired` - when starting a new submission for a retired form
- `invalidFormDefinition` - when the form has no sections, sheets or entries
- `referenceDataNotSet` - when the form's reference data is not stored on the device
- `submissionCompleted` - `showSubmission` only: when the submission is `closed` and can no longer be edited

#### Step 8: Read the result

The `completion` closure receives a JSON (see [Result format](#result-format)) where `data` contains the submission header, with the same properties as in [`getFormsAndSubmissions`](#step-6-get-the-forms-and-submissions):

```json
{
  "error": null,
  "data": {
    "guid": "0D1B5C2E-...",
    "name": "*** 09/24/26 10:15:02",
    "status": "closed",
    "last_saved_at": 1727172902,
    "dispatch_id": null,
    "deletable": false,
    "pendingUpload": true,
    "rejected": false
  }
}
```

Unlike the [Userless](#step-5-read-the-response) result, the entries' values are not returned: they are stored on the device and uploaded by the next `sync`.

#### Step 9: Sync again

Call [`sync`](#step-5-sync) again to upload the completed submissions (`pendingUpload: true`) and receive the latest forms, dispatches and handoffs. Use `uploadOnly: true` to only upload them.

### Other calls

#### deleteSubmission

```swift
public func deleteSubmission(username: String, guid: String) -> String
```

| Parameter | Description |
|---|---|
| `username` | the synced user's username |
| `guid` | the submission `guid`, as returned by `getFormsAndSubmissions` |

Deletes a saved submission from the device. It must not be called on the main thread. Returns a JSON (see [Result format](#result-format)) where, on success, `data` contains the deleted submission, with the same properties as in `getFormsAndSubmissions` (an empty object when no submission has that `guid`). Dispatches, handoffs and completed submissions cannot be deleted and return a `submissionCannotBeDeleted` error.

Possible errors: `noSyncedUser`, `invalidUser`, `submissionCannotBeDeleted`, `invalidSavedResponse` (when the submission could not be deleted from the device).

#### hasPendingSubmissions

```swift
public func hasPendingSubmissions() -> Bool
```

Takes no parameters and returns `true` when any submission on the device has `pendingUpload: true` (its `status` is `closed`), so it will be uploaded or finish uploading on the next `sync`. It must not be called on the main thread.

### Working offline

Once a user is synced, a network connection is needed only for `sync` and for viewing some media files of dispatches and handoffs:

- `getFormsAndSubmissions`, `showForm`, `showSubmission`, `deleteSubmission`, `hasPendingSubmissions` and `clearData` work offline, using the data stored on the device
- completed submissions stay on the device (`pendingUpload: true`) until the next successful `sync`
- photos, videos, signatures and attachments of dispatches and handoffs are downloaded only when the user taps on the field to view them while filling out the submission, so a network connection and a valid token are needed at that moment. Drawings are already on the device after `sync`

### User-based error codes

| Code | Name | When | Message |
|---|---|---|---|
| 90000 | invalidJson | when the form definition cannot be parsed, or the form is not found on the device | Unable to parse form definition. |
| 90001 | invalidFormDefinition | when the form has no sections, sheets or entries | Form definition is invalid. |
| 90002 | invalidSavedResponse | when the saved response cannot be restored, or the submission is not found on the device | Unable to resume response. |
| 90003 | referenceDataNotSet | when the form uses reference data that was not provided or is not stored on the device | Unable to show form. Reference data was not set. |
| 90004 | invalidLicenseKey | when the license key provided is not valid | License key is invalid, please contact your account manager for assistance. |
| 90005 | invalidPackageIdentifier | when the license key provided is not valid for the app's bundle identifier | Invalid package identifier, please contact your account manager for assistance. |
| 90006 | invalidUser | when the `username` does not match the synced user | The provided username does not match the user currently synced with the SDK. |
| 90007 | invalidToken | when the token has no `access_token` | The provided token is invalid or missing an access_token. |
| 90008 | networkError | when a request fails or the server rejects it | A network error occurred, please try again. |
| 90009 | syncFailed | when the sync fails for any other reason | Unable to complete sync, please try again. |
| 90010 | tokenUserMismatch | when the token belongs to a different user than `username` | The provided token is not valid for the specified user. |
| 90011 | differentUser | when another user is already synced on the device | A different user is already synced. Clear data before syncing a new user. |
| 90012 | noSyncedUser | when a call needs a synced user and none is synced yet | You must have a synced user first. |
| 90013 | formRetired | when starting a new submission for a retired form | This form has been retired and can no longer be used. |
| 90014 | syncInProgress | when `sync` is called while another sync is running | A sync is already in progress. |
| 90015 | submissionCannotBeDeleted | when the submission is a dispatch, a handoff or waiting to upload | This submission cannot be deleted and needs to be unassigned. |
| 90016 | submissionCompleted | when `showSubmission` is called for a `closed` submission | This submission has been completed and can no longer be edited. |
| 90017 | userModeConflict | when the Userless `formFlowController` is called for a form that is already synced for the user, or that uses reference data already synced for the user | Unable to show form. |

In Userless mode, `userModeConflict` is thrown as `FormLauncherError.userModeConflictError`.
