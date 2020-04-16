module Main exposing (..)

import Browser
import Browser.Dom as Dom exposing (Error(..), getElement)
import Browser.Events
    exposing
        ( onAnimationFrameDelta
        , onMouseDown
        , onMouseMove
        , onMouseUp
        , onResize
        )
import ColorWheel
import Dict exposing (Dict)
import Geometry as Geom exposing (..)
import Html exposing (Html, button, div, input, label, p, text)
import Html.Attributes as HA exposing (checked, src, type_, value)
import Html.Events exposing (onClick, onInput)
import HueGrid
import Json.Decode as Decode exposing (Decoder)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Munsell
    exposing
        ( ColorDict
        , MunsellColor
        , findColor
        , loadColors
        , munsellHueName
        )
import Result exposing (Result)
import Task
import WebGL exposing (Entity, Mesh, Shader)



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


type alias MouseEventLocation =
    { pageX : Float
    , pageY : Float
    , offsetX : Float
    , offsetY : Float
    }


type alias RelativePosition =
    { x : Float
    , y : Float
    }


type alias WindowSize =
    Rect Float


{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { windowRect : WindowSize
    , sceneElement : Maybe Dom.Element
    , camera : Camera
    , lastDragPosition : Maybe RelativePosition
    , colors : ColorDict
    , view : ColorView
    , hueIndex : String
    , value : String
    , animating : Bool
    , showBall : Bool
    , showCoordinates : Bool
    , ballMeshes : List AppMesh
    , wheelMeshes : Dict Int AppMesh
    , hueMesh : AppMesh
    }


cameraDistance : Float
cameraDistance =
    3 * ColorWheel.sceneSize


init : Flags -> ( Model, Cmd Msg )
init ts =
    let
        colors =
            loadColors
    in
    ( { windowRect = { width = 800.0, height = 800.0 }
      , sceneElement = Nothing
      , camera = makeCamera cameraDistance 0 0
      , lastDragPosition = Nothing
      , colors = colors
      , view = ColorWheelView
      , hueIndex = "0"
      , value = "7"
      , animating = False
      , showBall = False
      , showCoordinates = False
      , ballMeshes = ColorWheel.ballMeshes Geom.defaultBallColors ColorWheel.sceneSize
      , wheelMeshes = ColorWheel.wheelMeshes colors
      , hueMesh = buildHueGrid colors "0"
      }
    , Cmd.none
    )


buildHueGrid : ColorDict -> String -> AppMesh
buildHueGrid colors hueIndex =
    toHue hueIndex
        |> HueGrid.gridMesh colors


toValue : String -> Int
toValue value =
    String.toInt value |> Maybe.withDefault 7


toHue : String -> Int
toHue hueIndex =
    let
        hue =
            String.toInt hueIndex |> Maybe.withDefault 0
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
    | AnimatingCheckboxClicked
    | ShowBallCheckboxClicked
    | ShowCoordinatesCheckboxClicked
    | WindowResized WindowSize
    | MouseMoved MouseEventLocation
    | MouseWentDown MouseEventLocation
    | MouseWentUp MouseEventLocation


getSceneElementCmd : Cmd Msg
getSceneElementCmd =
    getElement "webgl-scene" |> Task.attempt GotSceneElement


{-| Number of pixels per second we are moving the camera via animation
-}
spinRate : Float
spinRate =
    0.0005


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FrameTimeUpdated dt ->
            let
                cmds =
                    case model.sceneElement of
                        Nothing ->
                            getSceneElementCmd

                        Just _ ->
                            Cmd.none

                nextModel =
                    case model.animating of
                        True ->
                            let
                                deltaX =
                                    dt * spinRate * model.windowRect.width
                            in
                            { model | camera = dragCamera cameraDistance deltaX 0 model.camera }

                        False ->
                            model
            in
            ( nextModel, cmds )

        GotSceneElement result ->
            case result of
                Ok element ->
                    ( { model | sceneElement = Just element }, Cmd.none )

                Err error ->
                    ( model, Cmd.none )

        ViewButtonClicked ->
            let
                nextView =
                    case model.view of
                        ColorWheelView ->
                            HueGridView

                        _ ->
                            ColorWheelView
            in
            ( { model | view = nextView }, Cmd.none )

        ValueInputChanged newValue ->
            ( { model | value = newValue }, Cmd.none )

        HueInputChanged newHueIndex ->
            ( { model
                | hueIndex = newHueIndex
                , hueMesh = buildHueGrid model.colors newHueIndex
              }
            , Cmd.none
            )

        AnimatingCheckboxClicked ->
            ( { model | animating = not model.animating }, Cmd.none )

        ShowBallCheckboxClicked ->
            ( { model | showBall = not model.showBall }, Cmd.none )

        ShowCoordinatesCheckboxClicked ->
            ( { model | showCoordinates = not model.showCoordinates }, Cmd.none )

        WindowResized rect ->
            ( { model | windowRect = rect }, getSceneElementCmd )

        MouseWentDown pos ->
            let
                ( offsetX, offsetY ) =
                    getOffsetRelativeTo model.sceneElement pos
            in
            ( { model | lastDragPosition = Just { x = offsetX, y = offsetY } }, Cmd.none )

        MouseWentUp pos ->
            let
                ( offsetX, offsetY ) =
                    getOffsetRelativeTo model.sceneElement pos
            in
            ( { model | lastDragPosition = Nothing }, Cmd.none )

        MouseMoved pos ->
            case model.lastDragPosition of
                Just { x, y } ->
                    let
                        ( offsetX, offsetY ) =
                            getOffsetRelativeTo model.sceneElement pos

                        camera =
                            dragCamera
                                cameraDistance
                                (x - offsetX)
                                (y - offsetY)
                                model.camera
                    in
                    ( { model
                        | camera = camera
                        , lastDragPosition = Just { x = offsetX, y = offsetY }
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )


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
mouseEventDecoder : (MouseEventLocation -> Msg) -> Decoder Msg
mouseEventDecoder tag =
    Decode.map4 MouseEventLocation
        (Decode.field "pageX" Decode.float)
        (Decode.field "pageY" Decode.float)
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)
        |> Decode.map tag


decodeMouseDown : Decoder Msg
decodeMouseDown =
    mouseEventDecoder MouseWentDown


decodeMouseUp : Decoder Msg
decodeMouseUp =
    mouseEventDecoder MouseWentUp


decodeMouseMove : Decoder Msg
decodeMouseMove =
    mouseEventDecoder MouseMoved


getOffsetRelativeTo : Maybe Dom.Element -> MouseEventLocation -> ( Float, Float )
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


toolboxWidth : Float
toolboxWidth =
    400.0


view : Model -> Html Msg
view model =
    div []
        [ div
            [ HA.style "position" "absolute"
            , HA.style "z-index" "1"
            , HA.style "left" "0px"
            , HA.style "top" "0px"
            ]
            [ viewMesh model ]
        , div
            [ HA.style "position" "absolute"
            , HA.style "z-index" "2"
            , HA.style "left" (String.fromFloat (model.windowRect.width - toolboxWidth) ++ "px")
            , HA.style "top" "0px"
            , HA.style "width" (String.fromFloat toolboxWidth ++ "px")
            , HA.style "text-align" "left"
            ]
            (viewSlider model
                ++ [ div []
                        [ button
                            [ type_ "button"
                            , onClick ViewButtonClicked
                            ]
                            [ text
                                (case model.view of
                                    ColorWheelView ->
                                        "Hue Grid Page"

                                    _ ->
                                        "Color Wheel Page"
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
                            , checked model.showBall
                            , onClick ShowBallCheckboxClicked
                            ]
                            []
                        , label [] [ text "Show Ball" ]
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


viewSlider : Model -> List (Html Msg)
viewSlider model =
    case model.view of
        ColorWheelView ->
            [ div []
                [ label [] [ text "Value" ]
                , input
                    [ type_ "range"
                    , HA.min "1"
                    , HA.max "9"
                    , value model.value
                    , onInput ValueInputChanged
                    ]
                    []
                ]
            , div []
                [ label [] [ text model.value ] ]
            ]

        HueGridView ->
            let
                hue =
                    toHue model.hueIndex

                nameLeft =
                    case munsellHueName (modBy 1000 (hue + 500)) of
                        Ok n ->
                            n

                        Err e ->
                            e

                nameRight =
                    case munsellHueName hue of
                        Ok n ->
                            n

                        Err e ->
                            e
            in
            [ div []
                [ label [] [ text "Hue" ]
                , input
                    [ type_ "range"
                    , HA.min "1"
                    , HA.max "39"
                    , value model.hueIndex
                    , onInput HueInputChanged
                    ]
                    []
                ]
            , div []
                [ label [] [ text (nameLeft ++ " " ++ nameRight) ] ]
            ]


viewCoordinates : Model -> List (Html Msg)
viewCoordinates model =
    case model.showCoordinates of
        True ->
            [ div []
                [ label [] [ text "Drag Pos X " ]
                , text
                    (case model.lastDragPosition of
                        Just { x } ->
                            String.fromFloat x

                        Nothing ->
                            ""
                    )
                ]
            , div []
                [ label [] [ text "Drag Pos Y " ]
                , text
                    (case model.lastDragPosition of
                        Just { y } ->
                            String.fromFloat y

                        Nothing ->
                            ""
                    )
                ]
            , div []
                [ label [] [ text "Camera X " ]
                , text (String.fromFloat <| Vec3.getX model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera Y " ]
                , text (String.fromFloat <| Vec3.getY model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera Z " ]
                , text (String.fromFloat <| Vec3.getZ model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera phi " ]
                , text (String.fromFloat <| model.camera.phi * 180 / pi)
                ]
            ]

        False ->
            []


viewMesh : Model -> Html Msg
viewMesh model =
    let
        ballMeshes =
            if model.showBall then
                model.ballMeshes

            else
                []
    in
    case model.view of
        ColorWheelView ->
            viewColorWheel
                model.windowRect
                model.camera
                (toValue model.value)
                ballMeshes
                model.wheelMeshes

        HueGridView ->
            viewHueGrids
                model.windowRect
                model.camera
                (model.hueMesh :: ballMeshes)



---- VIEW ----


toEntity : Uniforms -> AppMesh -> Entity
toEntity uniforms mesh =
    WebGL.entity
        vertexShader
        fragmentShader
        mesh
        uniforms


viewColorWheel : WindowSize -> Camera -> Int -> List AppMesh -> Dict Int AppMesh -> Html Msg
viewColorWheel { width, height } camera value ballMeshes meshes =
    let
        uniforms =
            makeUniforms width height ColorWheel.sceneSize camera
    in
    WebGL.toHtml
        [ HA.id "webgl-scene"
        , HA.width (truncate width)
        , HA.height (truncate height)
        , HA.style "display" "block"
        ]
        (List.range 1 value
            |> List.map (\v -> Dict.get v meshes)
            |> List.foldl
                (\m acc ->
                    case m of
                        Just mesh ->
                            toEntity uniforms mesh :: acc

                        Nothing ->
                            acc
                )
                (List.map (toEntity uniforms) ballMeshes)
        )


viewHueGrids : WindowSize -> Camera -> List AppMesh -> Html Msg
viewHueGrids { width, height } camera meshes =
    let
        uniforms =
            makeUniforms width height ColorWheel.sceneSize camera
    in
    WebGL.toHtml
        [ HA.id "webgl-scene"
        , HA.width (truncate width)
        , HA.height (truncate height)
        , HA.style "display" "block"
        ]
        (List.map (toEntity uniforms) meshes)



---- SHADERS ----


vertexShader : Shader Vertex Uniforms { vcolor : Vec3 }
vertexShader =
    [glsl|
        attribute vec3 position;
        attribute vec3 color;
        uniform mat4 camera;
        uniform mat4 perspective;
        varying vec3 vcolor;
        void main () {
            gl_Position = perspective * camera * vec4(position, 1.0);
            vcolor = color;
        }
    |]


fragmentShader : Shader {} Uniforms { vcolor : Vec3 }
fragmentShader =
    [glsl|
        precision mediump float;
        varying vec3 vcolor;
        void main () {
            gl_FragColor = vec4(vcolor, 1.0);
        }
    |]



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
        subAlways =
            Sub.batch
                [ onMouseDown decodeMouseDown
                , onMouseUp decodeMouseUp
                , onMouseMove decodeMouseMove
                , onResize (\w h -> WindowResized { width = toFloat w, height = toFloat h })
                ]
    in
    case ( model.sceneElement, model.animating ) of
        ( Just _, False ) ->
            subAlways

        _ ->
            Sub.batch [ onAnimationFrameDelta FrameTimeUpdated, subAlways ]
