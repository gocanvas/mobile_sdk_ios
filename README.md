# Go Canvas SDK for iOS

#### Table of contents:
- [Installation](#Installation)
- [Usage](#Usage)
- [Branding](#Branding)

## Installation

Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding GCSdk as a dependency is as easy as adding it to the dependencies value of your Package.swift or the Package list in Xcode.
```
dependencies: [
    .package(url: "https://github.com/gocanvas/mobile_sdk_ios.git", .upToNextMajor(from: "2.0.0"))
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

Go to **Build Settings** tab and search for **ENABLE_USER_SCRIPT_SANDBOXING** property. Set this property to **NO**. This is needed in order for the setup script from above to run succesfully.

## Usage

### App configurations

The application is required to populate their info.plist with the following fields:

|Key | Recomended value |
| -------------------------|-------------------------|
|NSCameraUsageDescription|Our app uses the camera to capture photos that are uploaded as part of your submission. |
|NSLocationWhenInUseUsageDescription|Allow location usage so when a GPS control is clicked the geolocation data can be saved and submitted.|
|NSLocationAlwaysUsageDescription|Allow location usage so when a GPS control is clicked the geolocation data can be saved and submitted.|
|NSMicrophoneUsageDescription|Microphone is used to capture videos during a submission.|
|NSPhotoLibraryUsageDescription|Photo Library is used to obtain photos during a submission.|
|NSLocationTemporaryUsageDescriptionDictionary||
|- WantAccuracy|Your precise location will be used in this submission.|

### SDK Api

#### General API
The Sdk provides the following api interface:
```swift

public class GoCanvasFormLauncher {

public init(config: GCSdkConfig)

@MainActor 
public func formFlowController(config: GCSdkFormConfig, 
                               messagingDelegate: any MessagingDelegate, 
                               completion: @escaping (String) -> ()) async throws -> UIViewController
}
```

#### Configuring the form launcher
The constructor takes the license key for the sdk.

```
public struct GCSdkConfig {
    public init(licenseKey: String)
}
```

#### Configuring the form 
The config parameter required to retrieve the controller of a form flow can be populated with a mandatory form, and a set of optional reference data or a set of optional prefilled data.

```
public struct GCSdkFormConfig {
    public init(jsonInput: String, 
                referenceDataJson: String? = nil,
                prefilledDataJson: String? = nil)
}
```

#### Retrieving special messages from the SDK

Through the MessagingDelegate, the SDK will request a specific action from the parent app.

The current use case for this is when a form has been previously completed partially, and we are requesting the application to tell us if the want to discard the previous action or if they want to continue. Calling the action handler on any of the MessaginAction objects offered in the delegate will decide the behavior of the form flow for the current session.
```
public struct MessagingAction {
    public let actionTitle: String
    public let actionHandler: () -> Void
}

public protocol MessagingDelegate {
    func showResumeMessage(withTitle: String,
                           body: String,
                           discardAction: MessagingAction,
                           continueAction: MessagingAction)
}

```


The SDK can be accessed by importing the GCSdk.

```swift
import GCSdk
```

### Display Form

In order to launch a form, you need to retrieve an instance of UIViewController and present it in your application's UI.
To retrieve the controller, you need to follow the above steps:

1. Instantiate the `FormLauncher` object using an instance of `GCSdkConfig`
2. Have an object you own implement `MessagingDelegate`
3. Use the `FormLauncher` object to retrieve a controller for a form flow using:
    - an instance of `GCSdkFormConfig` that must be populated with a form in JSON format. Optionally, you can input dispatches or sets of reference data as JSON.
    - an instance of a class implementing `MessagingDelegate`
    - a completion block used to handle retrieving the JSON after a succesfull submission
4. Handle possible errors

```swift
let licenseKey = rootViewController.viewModel.licenseKey ?? ""
let config = Config(licenseKey: licenseKey)
let formLauncher = FormLauncher(config: config)

do {
    let formConfig = FormConfig(jsonInput: json,
                                referenceDataJson: rootViewController.viewModel.referenceDataJson,
                                prefilledDataJson: rootViewController.viewModel.prefilledDataJson)
    try await formLauncher.formFlowController(config: config, messagingDelegate: self) { jsonResponse in 
        // handle submission json retrieval
    }
} catch {
    // handle error
}
```

SDK `json` param supports the `format=sync` form definition obtained through the GoCanvas API.

Example: `https://www.gocanvas.com/api/v3/forms/123456?format=sync`

### Receive Form Response

The response is being returned through the `String` parameter of the `launchForm` function's completion closure. The closure is being called at the end of the form flow when the user taps on *_Submit_* on the last page of the flow.

The response will be a `String` containing a JSON.

For media files, entries that populate images will contain paths to locally stored images written under the *_Value_* field. For multi image entries, multiple paths will be appended with a newline separator. 

### Resume Form Response

The SDK provides the ability to resume the form response in case of an app crash or of a partially form completion.

In order to do that, you just have to call the `formLauncher.formFlowController` method again by passing the same `jsonInput` input. The User will be prompted when there is a partially saved form response and he/she will be able to choose between resuming the form or starting a new submission of it.

### Errors

The SDK supports the following error types:

- `invalidJson` - when the `input` parameter cannot pe parsed to `Form`
- `missingData` - when the `Form` has no sections, sheets or entries
- `resumeFormFailed` - when the `Response` cannot be restored after partially form saving
- `missingCameraConfiguration` - when the app does not contain the required camera details in the info.plist
- `referenceDataError` - when a form expects reference data, but no correct reference data has been provided in the form config
- `formRetiredError` - when the version of the form is marked with 0, marked as retired
- `unknown` - when any other type of error has occured

Each error has an associated `message` that can be interrogated:

```swift
public enum FormLauncherError : Error {
    case invalidJson(userInfo: [String: Any], description: String)
    case missingData(description: String)
    case resumeFormFailed(description: String)
    case missingCameraConfiguration(description: String)
    case referenceDataError(description: String)
    case formRetiredError(description: String)
    case unknown(error: NSError)

    public var message: String { get }
}
```

#### Additional error details

For `invalidJson` error, there's a dictionary with the JSON parsing error attached, as defined by the platform's API.

For `unknown` error, there's an `NSError` object attached, defined by the platform.

The `message` property retrurns the following error messages:

- `invalidJson` - "Unable to parse form definition."
- `missingData` - "Form definition is invalid."
- `resumeFormFailed` - "Unable to resume response."
- `missingCameraConfiguration` - "Missing camera configuration in the main app."
- `referenceDataError` - "Reference data is incomplete"
- `formRetiredError` - "Form retired."
- `unknown` - Returns the `description` of the NSError object

## Branding
### Colors

The color system that can be used to create a color scheme that reflects your brand or style.

|Color Name | Default |
| -------------------------|--------------|
|gc_sdk_color_primary|![#039de7](https://placehold.co/15x15/039de7/039de7.png) #039de7 |
|gc_sdk_color_rating_selected|![#039de7](https://placehold.co/15x15/039de7/039de7.png) #039de7|
|gc_sdk_color_secondary|![#00bfa5](https://placehold.co/15x15/00bfa5/00bfa5.png) #00bfa5|
 
By overriding this color attribute, you can easily change the style of the customizable components used by the sdk.

****Applying your own colors:****

In order to use your color as the theme for the form flow, a `Color Set` must be added to any `xcasset` available in your target with the following names: 
- `gc_sdk_color_primary`
- `gc_sdk_color_rating_selected`
- `gc_sdk_color_secondary`
