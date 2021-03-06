module Main exposing (..)

import Angle exposing (Angle)
import Browser
import Browser.Dom as Dom exposing (Error(..), getElement, getViewport)
import Browser.Events
    exposing
        ( onAnimationFrameDelta
        , onMouseDown
        , onMouseMove
        , onMouseUp
        , onResize
        )
import Camera3d exposing (Camera3d)
import Color
import ColorWheel
import Dict exposing (Dict)
import Direction3d exposing (Direction3d)
import Html exposing (Html, button, div, input, label, text)
import Html.Attributes as HA exposing (checked, type_, value)
import Html.Events exposing (onClick, onInput)
import HueGrid
import Json.Decode as Decode exposing (Decoder)
import Length exposing (Length, Meters)
import Munsell exposing (ColorDict)
import Pixels
import Point3d
import Quantity
import Result exposing (Result)
import Scene3d
import SketchPlane3d
import Task
import Viewpoint3d
import World exposing (GlobeColors, WorldCoordinates, WorldEntityList)


{-| Modules from other packages imported by ianmackenzie/elm-3d-scene

Angle, Length, Pixels, Quantity from ianmackenzie/elm-units
Arc3d, Axis3d, Block3d, Cylinder3d, Direction3d, Frame3d, Point3d, Sphere3d from ianmackenzie/elm-geometry
Camera3d, SketchPlane3d, Viewpoint3d from ianmackenzie/elm-3d-camera
Color from tesk9/palette package
Scene3d from ianmackenzie/elm-3d-scene

-}



---- MODEL ----


type alias Flags =
    Int


type ColorView
    = ColorWheelView
    | HueGridView


type alias Rect a =
    { width : a
    , height : a
    }


{-| Size in browser pixels.
-}
type alias WindowSize =
    Rect Int


type alias Camera =
    Camera3d Meters World.WorldCoordinates


{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { windowSize : WindowSize
    , azimuth : Angle
    , elevation : Angle
    , orbiting : Bool
    , colors : ColorDict
    , view : ColorView
    , munsellHueIndex : String
    , munsellValue : String
    , cameraDistance : String
    , animating : Bool
    , showGlobe : Bool
    , showCoordinates : Bool
    , globe : WorldEntityList
    , colorWheel : Dict Int WorldEntityList
    , hueGrid : WorldEntityList
    }



-- CONSTANTS
{- These are in centimeters. -}


sceneRadius : Float
sceneRadius =
    max ColorWheel.sceneRadius HueGrid.sceneRadius


clipDepth : Float
clipDepth =
    0.1 * sceneRadius


initialCameraDistance : Float
initialCameraDistance =
    5 * sceneRadius


initialWidth : Int
initialWidth =
    800


initialAzimuthDegrees : Float
initialAzimuthDegrees =
    45.0


initialElevationDegrees : Float
initialElevationDegrees =
    30.0



-- INIT


init : Flags -> ( Model, Cmd Msg )
init _ =
    let
        colors =
            Munsell.loadColors
    in
    ( { windowSize = { width = initialWidth, height = initialWidth }
      , azimuth = Angle.degrees initialAzimuthDegrees
      , elevation = Angle.degrees initialElevationDegrees
      , orbiting = False
      , colors = colors
      , view = ColorWheelView
      , munsellHueIndex = "0"
      , munsellValue = "7"
      , cameraDistance = String.fromFloat initialCameraDistance
      , animating = False
      , showGlobe = False
      , showCoordinates = False
      , globe = buildGlobe
      , colorWheel = ColorWheel.wheel colors
      , hueGrid = buildHueGrid colors "0"
      }
    , Task.perform
        (\{ viewport } -> WindowResized { width = truncate viewport.width, height = truncate viewport.height })
        getViewport
    )



---- ENTITIES: POLYLINE GLOBE POLYLINES


defaultGlobeColors : GlobeColors
defaultGlobeColors =
    { xPos = Color.rgb255 255 0 0
    , xNeg = Color.rgb255 0 255 0
    , yPos = Color.rgb255 150 150 0
    , yNeg = Color.rgb255 0 150 150
    , oPos = Color.rgb255 0 0 255
    , oNeg = Color.rgb255 150 0 150
    }


buildGlobe : WorldEntityList
buildGlobe =
    World.globe (Length.centimeters sceneRadius) defaultGlobeColors


buildHueGrid : ColorDict -> String -> WorldEntityList
buildHueGrid colors munsellHueIndex =
    stringToHue munsellHueIndex
        |> HueGrid.gridForHue colors


stringToValue : String -> Int
stringToValue value =
    String.toInt value |> Maybe.withDefault 7


stringToHue : String -> Int
stringToHue munsellHueIndex =
    let
        hue =
            String.toInt munsellHueIndex |> Maybe.withDefault 0
    in
    hue * 25



---- UPDATE ----


type alias SceneElementResult =
    Result Dom.Error Dom.Element


type Msg
    = FrameTimeUpdated Float
    | GotSceneElement SceneElementResult
    | ViewButtonClicked
    | ValueInputChanged String
    | HueInputChanged String
    | CameraDistanceInputChanged String
    | AnimatingCheckboxClicked
    | ShowBallCheckboxClicked
    | ShowCoordinatesCheckboxClicked
    | WindowResized WindowSize
    | MouseMoved Float Float
    | MouseWentDown
    | MouseWentUp


{-| Number of pixels per second we are moving the camera via animation
-}
spinRate : Float
spinRate =
    0.005


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FrameTimeUpdated _ ->
            let
                newModel =
                    if model.animating then
                        let
                            dx =
                                spinRate * 360.0

                            newAzimuth =
                                model.azimuth |> Quantity.minus (Angle.degrees dx)
                        in
                        { model | azimuth = clampedAzimuth newAzimuth }

                    else
                        model
            in
            ( newModel, Cmd.none )

        GotSceneElement _ ->
            ( model, Cmd.none )

        ViewButtonClicked ->
            let
                newView =
                    case model.view of
                        ColorWheelView ->
                            HueGridView

                        _ ->
                            ColorWheelView
            in
            ( { model | view = newView }, Cmd.none )

        ValueInputChanged newMunsellValue ->
            ( { model | munsellValue = newMunsellValue }, Cmd.none )

        HueInputChanged newMunsellHueIndex ->
            ( { model
                | munsellHueIndex = newMunsellHueIndex
                , hueGrid = buildHueGrid model.colors newMunsellHueIndex
              }
            , Cmd.none
            )

        CameraDistanceInputChanged newCameraDistance ->
            ( { model | cameraDistance = newCameraDistance }, Cmd.none )

        AnimatingCheckboxClicked ->
            ( { model | animating = not model.animating }, Cmd.none )

        ShowBallCheckboxClicked ->
            ( { model | showGlobe = not model.showGlobe }, Cmd.none )

        ShowCoordinatesCheckboxClicked ->
            ( { model | showCoordinates = not model.showCoordinates }, Cmd.none )

        WindowResized rect ->
            ( { model | windowSize = rect }, Cmd.none )

        MouseWentDown ->
            ( { model | orbiting = True }, Cmd.none )

        MouseWentUp ->
            ( { model | orbiting = False }, Cmd.none )

        MouseMoved dx dy ->
            if model.orbiting then
                let
                    newAzimuth =
                        model.azimuth
                            |> Quantity.minus (Angle.degrees dx)

                    newElevation =
                        model.elevation
                            |> Quantity.plus (Angle.degrees dy)
                in
                ( { model | azimuth = clampedAzimuth newAzimuth, elevation = clampedElevation newElevation }
                , Cmd.none
                )

            else
                ( model, Cmd.none )


clampedAzimuth : Angle -> Angle
clampedAzimuth az =
    if Quantity.lessThan (Angle.degrees -180) az then
        Quantity.plus (Angle.degrees 360) az

    else if Quantity.greaterThan (Angle.degrees 180) az then
        Quantity.minus (Angle.degrees 360) az

    else
        az


clampedElevation : Angle -> Angle
clampedElevation el =
    Quantity.clamp
        (Angle.degrees -90)
        (Angle.degrees 90)
        el


{-| mousedown, mouseup and mousemove events have the following values.

target : topmost event target
view : Window
screenX : X position in global (screen) coordinates
screenY : Y position in global (screen) coordinates
clientX : X position within the viewport (client area)
clientY : Y position within the viewport (client area)
pageX : X position relative to the left edge of the entire document
pageY : Y position relative to the top edge to the entire document
offsetX : X position relative to the lef padding edge of the target node
offsetY : Y position relative to the lef padding edge of the target node
altKey : true if Alt modifier was active, otherwise false
ctrlKey : true if Control modifier was active, otherwise false
shiftKey : true if Shift modifier was active, otherwise false
metaKey : true if Meta modifier was active, otherwise false
buttons : bitmap of mouse buttons that were pressed

mousemove events also have the following values.

movementX : difference in X coordinate between the given event and the previous MouseMoved event
movementY : difference in Y coordinate between the given event and the previous MouseMoved event

Note: offsetX and offsetY are not supported in all browsers.
The workaround is to use getElement to find the x and y
position of the target relative to the entire document,
and then subtract.

-}
decodeMouseDown : Decoder Msg
decodeMouseDown =
    Decode.succeed MouseWentDown


decodeMouseUp : Decoder Msg
decodeMouseUp =
    Decode.succeed MouseWentUp


decodeMouseMove : Decoder Msg
decodeMouseMove =
    Decode.map2 MouseMoved
        (Decode.field "movementX" Decode.float)
        (Decode.field "movementY" Decode.float)


{-| Not used.
-}
getSceneElementCmd : (SceneElementResult -> Msg) -> Cmd Msg
getSceneElementCmd tag =
    getElement "webgl-scene" |> Task.attempt tag


{-| Not used.
-}
getOffsetRelativeTo : Maybe Dom.Element -> { pageX : Float, pageY : Float, offsetX : Float, offsetY : Float } -> ( Float, Float )
getOffsetRelativeTo target { pageX, pageY, offsetX, offsetY } =
    case target of
        Just { element } ->
            let
                relativeX =
                    pageX - element.x

                relativeY =
                    pageY - element.y
            in
            ( relativeX, relativeY )

        Nothing ->
            ( offsetX, offsetY )



---- VIEW ----


getCamera : Angle -> Angle -> Length -> ( Camera3d Meters WorldCoordinates, Direction3d WorldCoordinates )
getCamera azimuth elevation cameraDistance =
    let
        viewpoint =
            Viewpoint3d.orbit
                { focalPoint = Point3d.origin
                , groundPlane = SketchPlane3d.xy
                , azimuth = azimuth
                , elevation = elevation
                , distance = cameraDistance
                }
    in
    ( Camera3d.perspective
        { viewpoint = viewpoint
        , verticalFieldOfView = Angle.degrees 30
        }
    , Viewpoint3d.viewDirection viewpoint
    )


toolboxWidth : Int
toolboxWidth =
    400


view : Model -> Html Msg
view model =
    div []
        [ div
            [ HA.style "position" "absolute"
            , HA.style "z-index" "1"
            , HA.style "left" "0px"
            , HA.style "top" "0px"
            ]
            [ viewScene model ]
        , div
            [ HA.style "position" "absolute"
            , HA.style "z-index" "2"
            , HA.style "left" (String.fromInt (model.windowSize.width - toolboxWidth) ++ "px")
            , HA.style "top" "0px"
            , HA.style "width" (String.fromInt toolboxWidth ++ "px")
            , HA.style "text-align" "left"
            ]
            (viewSliders model
                ++ [ div []
                        [ button
                            [ type_ "button"
                            , onClick ViewButtonClicked
                            ]
                            [ text
                                (case model.view of
                                    ColorWheelView ->
                                        "Switch to Hue Grid"

                                    _ ->
                                        "Switch to Color Wheel"
                                )
                            ]
                        ]
                   , div []
                        [ input
                            [ type_ "checkbox"
                            , checked model.animating
                            , onClick AnimatingCheckboxClicked
                            ]
                            []
                        , label [] [ text "Animating" ]
                        ]
                   , div []
                        [ input
                            [ type_ "checkbox"
                            , checked model.showGlobe
                            , onClick ShowBallCheckboxClicked
                            ]
                            []
                        , label [] [ text "Show Globe" ]
                        ]
                   , div []
                        [ input
                            [ type_ "checkbox"
                            , checked model.showCoordinates
                            , onClick ShowCoordinatesCheckboxClicked
                            ]
                            []
                        , label [] [ text "Show Coordinates" ]
                        ]
                   ]
                ++ viewCoordinates model
            )
        ]


viewSliders : Model -> List (Html Msg)
viewSliders model =
    case model.view of
        ColorWheelView ->
            viewValueSlider model.munsellValue ++ viewCameraSlider model.cameraDistance

        HueGridView ->
            viewHueSlider model.munsellHueIndex ++ viewCameraSlider model.cameraDistance


viewValueSlider : String -> List (Html Msg)
viewValueSlider munsellValue =
    [ div []
        [ label [] [ text "Value" ]
        , input
            [ type_ "range"
            , HA.min "1"
            , HA.max "9"
            , value munsellValue
            , onInput ValueInputChanged
            ]
            []
        ]
    , div []
        [ label [] [ text munsellValue ] ]
    ]


viewHueSlider : String -> List (Html Msg)
viewHueSlider munsellHueIndex =
    let
        hueRight =
            stringToHue munsellHueIndex

        hueLeft =
            modBy 1000 (hueRight + 500)

        nameLeft =
            Munsell.munsellHueName hueLeft
                |> Maybe.withDefault ("No hue for " ++ String.fromInt hueLeft)

        nameRight =
            Munsell.munsellHueName hueRight
                |> Maybe.withDefault ("No hue for " ++ String.fromInt hueRight)
    in
    [ div []
        [ label [] [ text "Hue" ]
        , input
            [ type_ "range"
            , HA.min "1"
            , HA.max "39"
            , value munsellHueIndex
            , onInput HueInputChanged
            ]
            []
        ]
    , div []
        [ label [] [ text (nameLeft ++ " " ++ nameRight) ] ]
    ]


viewCameraSlider : String -> List (Html Msg)
viewCameraSlider distance =
    [ div []
        [ label [] [ text "Zoom" ]
        , input
            [ type_ "range"
            , HA.min (String.fromInt (truncate initialCameraDistance // 4))
            , HA.max (String.fromInt (truncate initialCameraDistance))
            , value distance
            , onInput CameraDistanceInputChanged
            ]
            []
        ]
    , div []
        [ label [] [ text distance ] ]
    ]


viewCoordinates : Model -> List (Html Msg)
viewCoordinates model =
    if model.showCoordinates then
        [ div []
            [ label [] [ text "Azimuth " ]
            , text <| String.fromInt <| truncate <| Angle.inDegrees model.azimuth
            ]
        , div []
            [ label [] [ text "Elevation " ]
            , text <| String.fromInt <| truncate <| Angle.inDegrees model.elevation
            ]
        ]

    else
        []


viewScene : Model -> Html Msg
viewScene model =
    let
        cameraDistance =
            String.toFloat model.cameraDistance
                |> Maybe.withDefault initialCameraDistance
                |> Length.centimeters

        ( camera, sunlightDirection ) =
            getCamera model.azimuth model.elevation cameraDistance

        globe =
            if model.showGlobe then
                model.globe

            else
                []

        scene =
            case model.view of
                ColorWheelView ->
                    colorWheelForValue (stringToValue model.munsellValue) model.colorWheel

                HueGridView ->
                    model.hueGrid
    in
    div
        [ HA.id "webgl-scene"
        , HA.width model.windowSize.width
        , HA.height model.windowSize.height
        , HA.style "display" "block"
        ]
        [ Scene3d.sunny
            { dimensions = ( Pixels.pixels model.windowSize.width, Pixels.pixels model.windowSize.height )
            , sunlightDirection = sunlightDirection
            , upDirection = Direction3d.z
            , camera = camera
            , clipDepth = Length.centimeters clipDepth
            , background = Scene3d.transparentBackground
            , shadows = False
            , entities = scene ++ globe
            }
        ]



---- VIEW ----


colorWheelForValue : Int -> Dict Int WorldEntityList -> WorldEntityList
colorWheelForValue value wheel =
    List.range 1 value
        |> List.filterMap (\v -> Dict.get v wheel)
        |> List.concat



---- PROGRAM ----


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        browserSubs =
            onResize (\width height -> WindowResized { width = width, height = height })

        animationSubs =
            if model.animating then
                onAnimationFrameDelta FrameTimeUpdated

            else
                Sub.none

        mouseSubs =
            if model.orbiting then
                Sub.batch
                    [ onMouseMove decodeMouseMove
                    , onMouseUp decodeMouseUp
                    ]

            else
                onMouseDown decodeMouseDown
    in
    Sub.batch [ browserSubs, animationSubs, mouseSubs ]
