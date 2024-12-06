# Getting Started

## Installation

Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding GCSdk as a dependency is as easy as adding it to the dependencies value of your Package.swift or the Package list in Xcode.
```
dependencies: [
.package(url: "https://github.com/gocanvas/mobile_sdk_ios.git", .upToNextMajor(from: "1.0.0"))
]
```

# Usage

### SDK Api

The Sdk provides the following api interface:
```swift
public class GoCanvasFormLauncher {

public init()

///  Pushes the form flow in the navigation controller. Form is initialized using the input string.
///
///  - **parameter**  input: JSON input used to initialize the form
///  - **parameter**  input: Navigation controller used to push the form flow
///  - **parameter**  input: Closure that returns a JSON format string with the submission details
///  - **throws**: FormLauncherError
@MainActor
public func launchForm(withJSONinput input: String,
                       inNavigationController navigationController: UINavigationController,
                       completion: @escaping (String) -> ()) async throws
```

It can be accessed by importing the GCSdk.

```swift
import GCSdk
```

### Display Form

In order to launch the form flow, make sure you have a json `String` with the form details and an instance of `UIViewController` to pass in as parameters to `launchForm` function.
```swift
let formLauncher = FormLauncher()

do {
try await formLauncher.launchForm(withJSONinput: input, inNavigationController: navigationController) { submissionJsonResponse in
        // handle submission json retrieval
    }
} catch {
    // handle error
}
```
### Receive Form Response

The response is being returned through the `String` parameter of the `launchForm` function's completion closure. The closure is being called at the end of the form flow when the user taps on *_Submit_* on the last page of the flow.

The response will be a `String` containing a JSON.

### Resume Form Response

The SDK provides the ability to resume the form response in case of an app crash or of a partially form completion.

In order to do that, you just have to call the `launchForm` method again by passing the same `String` input. The User will be prompted when there is a partially saved form response and they will be able to choose between resuming the form or starting a new submission of it.

### Errors

The SDK supports the following error types:

- `invalidJson` - when the `input` parameter cannot pe parsed to `Form`
- `missingData` - when the `Form` has no sections, sheets or entries
- `resumeFormFailed` - when the `Response` cannot be restored after partially form saving
- `unknown` - when any other type of error has occured

Each error has an associated `message` that can be interrogated:

```swift
public enum FormLauncherError : Error {
    case invalidJson(userInfo: [String : Any], description: String)
    case missingData(description: String)
    case resumeFormFailed(description: String)
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
- `unknown` - Returns the `description` of the NSError object

# Colors

The color system that can be used to create a color scheme that reflects your brand or style.

|Color Name | Default |
| -------------------------|--------------|
|gc_sdk_color_primary|![#039de7](https://placehold.co/15x15/039de7/039de7.png) #039de7 |
 
By overriding this color attribute, you can easily change the style of the customizable components used by the sdk.

****Applying your own colors:****

In order to use your color as the theme for the form flow, a `Color Set` must be added to any `xcasset` available in your target with the following name: `gc_sdk_color_primary`
