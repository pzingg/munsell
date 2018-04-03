module Main exposing (..)

import AnimationFrame
import Dict exposing (Dict)
import Html exposing (Html, div, p, text, label, input, button)
import Html.Attributes as HA exposing (type_, value, src, width, height, style, checked)
import Html.Events exposing (onClick, onInput)
import WebGL exposing (Mesh, Shader, Entity)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Time exposing (Time)
import Task
import Window
import ElementRelativeMouseEvents exposing (Point, onMouseDown, onMouseUp, onMouseMove)
import Geometry as Geom exposing (..)
import ColorWheel
import HueGrid
import Munsell
    exposing
        ( MunsellColor
        , ColorDict
        , munsellHueName
        , numericFromString
        , findColor
        , loadColors
        )


---- MODEL ----


type ColorView
    = ColorWheelView
    | HueGridView


{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { windowRect : Window.Size
    , camera : Camera
    , lastDragPosition : Maybe Point
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


init : ( Model, Cmd Msg )
init =
    let
        colors =
            loadColors
    in
        ( { windowRect = Window.Size 800 800
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
        , Task.perform WindowResize Window.size
        )


buildHueGrid : ColorDict -> String -> AppMesh
buildHueGrid colors hueIndex =
    toHue hueIndex
        |> HueGrid.gridMesh colors


toValue : String -> Int
toValue value =
    String.toInt value |> numericFromString 7


toHue : String -> Int
toHue hueIndex =
    let
        hue =
            String.toInt hueIndex |> numericFromString 0
    in
        hue * 25



---- UPDATE ----


type Msg
    = FrameTick Time
    | ToggleView
    | ValueInput String
    | HueIndexInput String
    | AnimatingClick
    | ShowBallClick
    | ShowCoordinatesClick
    | WindowResize Window.Size
    | MouseDown Point
    | MouseUp Point
    | MouseMove Point


{-| Number of pixels per second we are dragging via animation
-}
dragRate : Float
dragRate =
    0.5


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FrameTick dt ->
            let
                model_ =
                    case model.animating of
                        True ->
                            let
                                deltaX =
                                    Time.inSeconds dt * dragRate * toFloat model.windowRect.width
                            in
                                { model | camera = dragCamera cameraDistance deltaX 0 model.camera }

                        False ->
                            model
            in
                ( model_, Cmd.none )

        ToggleView ->
            let
                nextView =
                    case model.view of
                        ColorWheelView ->
                            HueGridView

                        _ ->
                            ColorWheelView
            in
                ( { model | view = nextView }, Cmd.none )

        ValueInput newValue ->
            ( { model | value = newValue }, Cmd.none )

        HueIndexInput newHueIndex ->
            ( { model
                | hueIndex = newHueIndex
                , hueMesh = buildHueGrid model.colors newHueIndex
              }
            , Cmd.none
            )

        AnimatingClick ->
            ( { model | animating = not model.animating }, Cmd.none )

        ShowBallClick ->
            ( { model | showBall = not model.showBall }, Cmd.none )

        ShowCoordinatesClick ->
            ( { model | showCoordinates = not model.showCoordinates }, Cmd.none )

        WindowResize size ->
            ( { model | windowRect = size }, Cmd.none )

        MouseDown position ->
            ( { model | lastDragPosition = Just position }, Cmd.none )

        MouseUp position ->
            ( { model | lastDragPosition = Nothing }, Cmd.none )

        MouseMove position ->
            case model.lastDragPosition of
                Just lastPosition ->
                    let
                        camera =
                            dragCamera
                                cameraDistance
                                (position.x - lastPosition.x)
                                (position.y - lastPosition.y)
                                model.camera
                    in
                        ( { model
                            | camera = camera
                            , lastDragPosition = Just position
                          }
                        , Cmd.none
                        )

                Nothing ->
                    ( model, Cmd.none )



---- VIEW ----


toolboxWidth : Int
toolboxWidth =
    400


view : Model -> Html Msg
view model =
    div []
        [ div
            [ style
                [ ( "position", "absolute" )
                , ( "z-index", "1" )
                , ( "left", "0px" )
                , ( "top", "0px" )
                ]
            ]
            [ viewMesh model ]
        , div
            [ style
                [ ( "position", "absolute" )
                , ( "z-index", "2" )
                , ( "left", toString (model.windowRect.width - toolboxWidth) ++ "px" )
                , ( "top", "0px" )
                , ( "width", toString toolboxWidth ++ "px" )
                , ( "text-align", "left" )
                ]
            ]
            (viewSlider model
                ++ [ div []
                        [ button
                            [ type_ "button"
                            , onClick ToggleView
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
                            , onClick AnimatingClick
                            ]
                            []
                        , label [] [ text "Animating" ]
                        ]
                   , div []
                        [ input
                            [ type_ "checkbox"
                            , checked model.showBall
                            , onClick ShowBallClick
                            ]
                            []
                        , label [] [ text "Show Ball" ]
                        ]
                   , div []
                        [ input
                            [ type_ "checkbox"
                            , checked model.showCoordinates
                            , onClick ShowCoordinatesClick
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
                    , onInput ValueInput
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
                    case munsellHueName ((hue + 500) % 1000) of
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
                        , onInput HueIndexInput
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
                        Just pos ->
                            toString <| pos.x

                        Nothing ->
                            ""
                    )
                ]
            , div []
                [ label [] [ text "Drag Pos Y " ]
                , text
                    (case model.lastDragPosition of
                        Just pos ->
                            toString <| pos.y

                        Nothing ->
                            ""
                    )
                ]
            , div []
                [ label [] [ text "Camera X " ]
                , text (toString <| Vec3.getX model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera Y " ]
                , text (toString <| Vec3.getY model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera Z " ]
                , text (toString <| Vec3.getZ model.camera.position)
                ]
            , div []
                [ label [] [ text "Camera phi " ]
                , text (toString <| model.camera.phi * 180 / pi)
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


viewColorWheel : Window.Size -> Camera -> Int -> List AppMesh -> Dict Int AppMesh -> Html Msg
viewColorWheel windowRect camera value ballMeshes meshes =
    let
        w =
            toFloat windowRect.width

        h =
            toFloat windowRect.height

        uniforms =
            makeUniforms w h ColorWheel.sceneSize camera
    in
        WebGL.toHtml
            [ width windowRect.width
            , height windowRect.height
            , style [ ( "display", "block" ) ]
            , onMouseDown MouseDown
            , onMouseUp MouseUp
            , onMouseMove MouseMove
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


viewHueGrids : Window.Size -> Camera -> List AppMesh -> Html Msg
viewHueGrids windowRect camera meshes =
    let
        w =
            toFloat windowRect.width

        h =
            toFloat windowRect.height

        uniforms =
            makeUniforms w h ColorWheel.sceneSize camera
    in
        WebGL.toHtml
            [ width windowRect.width
            , height windowRect.height
            , style [ ( "display", "block" ) ]
            , onMouseDown MouseDown
            , onMouseUp MouseUp
            , onMouseMove MouseMove
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


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        subAlways =
            Window.resizes WindowResize
    in
        case model.animating of
            True ->
                Sub.batch [ AnimationFrame.diffs FrameTick, subAlways ]

            False ->
                subAlways
