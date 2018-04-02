module Main exposing (..)

import AnimationFrame
import Dict exposing (Dict)
import Html exposing (Html, div, p, text, label, input, button)
import Html.Attributes as HA exposing (type_, value, src, width, height, style, checked)
import Html.Events exposing (onClick, onInput)
import WebGL exposing (Mesh, Shader)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Time exposing (Time)
import Task
import Window
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
    , cameraPosition : Vec3
    , colors : ColorDict
    , view : ColorView
    , hueIndex : String
    , value : String
    , frozen : Bool
    , theta : Float
    , wheelMeshes : Dict Int AppMesh
    , hueMesh : Maybe AppMesh
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
          , cameraPosition = vec3 0 0 cameraDistance
          , colors = colors
          , view = ColorWheelView
          , hueIndex = "0"
          , value = "7"
          , frozen = True
          , theta = 0
          , wheelMeshes = ColorWheel.buildMeshes colors
          , hueMesh = Nothing
          }
        , Task.perform Resize Window.size
        )


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
    = Resize Window.Size
    | FrameTick Time
    | ToggleView
    | ValueInput String
    | HueIndexInput String
    | Freeze


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Resize size ->
            ( { model | windowRect = size }, Cmd.none )

        FrameTick dt ->
            let
                model_ =
                    case model.frozen of
                        True ->
                            model

                        False ->
                            let
                                theta =
                                    model.theta + (dt / 1000.0)

                                cameraPosition =
                                    vec3 (cameraDistance * sin theta) 0 (cameraDistance * cos theta)
                            in
                                { model | theta = theta, cameraPosition = cameraPosition }
            in
                ( model_, Cmd.none )

        ToggleView ->
            case model.view of
                ColorWheelView ->
                    let
                        mesh =
                            toHue model.hueIndex
                                |> HueGrid.buildMesh model.colors
                    in
                        ( { model | view = HueGridView, hueMesh = Just mesh }, Cmd.none )

                _ ->
                    ( { model | view = ColorWheelView }, Cmd.none )

        ValueInput newValue ->
            ( { model | value = newValue }, Cmd.none )

        HueIndexInput newHueIndex ->
            let
                mesh =
                    toHue newHueIndex
                        |> HueGrid.buildMesh model.colors
            in
                ( { model | hueIndex = newHueIndex, hueMesh = Just mesh }, Cmd.none )

        Freeze ->
            ( { model | frozen = not model.frozen }, Cmd.none )



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
            [ viewSlider model
            , div []
                [ button
                    [ type_ "button"
                    , onClick ToggleView
                    ]
                    [ text "Toggle View" ]
                ]
            , div []
                [ label [] [ text "Camera X " ]
                , text (toString <| Vec3.getX model.cameraPosition)
                ]
            , div []
                [ label [] [ text "Camera Y " ]
                , text (toString <| Vec3.getY model.cameraPosition)
                ]
            , div []
                [ label [] [ text "Camera Z " ]
                , text (toString <| Vec3.getZ model.cameraPosition)
                ]
            , div []
                [ input
                    [ type_ "checkbox"
                    , checked model.frozen
                    , onClick Freeze
                    ]
                    []
                , label [] [ text "Freeze" ]
                ]
            ]
        ]


viewSlider : Model -> Html Msg
viewSlider model =
    case model.view of
        ColorWheelView ->
            div []
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

        HueGridView ->
            div []
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


viewMesh : Model -> Html Msg
viewMesh model =
    case model.view of
        ColorWheelView ->
            viewColorWheel model.wheelMeshes model.windowRect model.cameraPosition (toValue model.value)

        HueGridView ->
            case model.hueMesh of
                Just mesh ->
                    viewHueGrid model.windowRect model.cameraPosition mesh

                Nothing ->
                    p [] [ text "No mesh!" ]



---- VIEW ----


viewColorWheel : Dict Int AppMesh -> Window.Size -> Vec3 -> Int -> Html msg
viewColorWheel meshes windowRect eye value =
    let
        w =
            toFloat windowRect.width

        h =
            toFloat windowRect.height
    in
        WebGL.toHtml
            [ width windowRect.width
            , height windowRect.height
            , style [ ( "display", "block" ) ]
            ]
            (List.range 1 value
                |> List.map (\v -> Dict.get v meshes)
                |> List.foldl
                    (\m acc ->
                        case m of
                            Just mesh ->
                                WebGL.entity
                                    vertexShader
                                    fragmentShader
                                    mesh
                                    (makeUniforms w h ColorWheel.sceneSize eye)
                                    :: acc

                            Nothing ->
                                acc
                    )
                    []
            )


viewHueGrid : Window.Size -> Vec3 -> AppMesh -> Html Msg
viewHueGrid windowRect eye mesh =
    let
        w =
            toFloat windowRect.width

        h =
            toFloat windowRect.height
    in
        WebGL.toHtml
            [ width windowRect.width
            , height windowRect.height
            , style [ ( "display", "block" ) ]
            ]
            [ WebGL.entity
                vertexShader
                fragmentShader
                mesh
                (makeUniforms w h ColorWheel.sceneSize eye)
            ]



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
    case model.frozen of
        True ->
            Window.resizes Resize

        False ->
            Sub.batch
                [ Window.resizes Resize
                , AnimationFrame.diffs FrameTick
                ]
