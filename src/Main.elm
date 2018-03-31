module Main exposing (..)

import AnimationFrame
import Dict exposing (Dict)
import Html exposing (Html, div, p, text, input, button)
import Html.Attributes as HA exposing (type_, value, src, width, height, style, checked)
import Html.Events exposing (onClick, onInput)
import WebGL exposing (Mesh, Shader)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Time exposing (Time)
import Task
import Window
import Geometry exposing (..)
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
    { window : Window.Size
    , colors : ColorDict
    , view : ColorView
    , hueIndex : String
    , value : String
    , frozen : Bool
    , theta : Float
    , wheelMeshes : Dict Int AppMesh
    , hueMesh : Maybe AppMesh
    }


init : ( Model, Cmd Msg )
init =
    let
        colors =
            loadColors
    in
        ( { window = Window.Size 800 800
          , colors = colors
          , view = ColorWheelView
          , hueIndex = "0"
          , value = "7"
          , frozen = True
          , theta = 0.5 * Basics.pi
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
            ( { model | window = size }, Cmd.none )

        FrameTick dt ->
            let
                model_ =
                    case model.frozen of
                        True ->
                            model

                        False ->
                            { model | theta = model.theta + (dt / 1000.0) }
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


view : Model -> Html Msg
view model =
    List.concat
        [ viewSlider model
        , [ input
                [ type_ "checkbox"
                , checked model.frozen
                , onClick Freeze
                ]
                []
          , text "Freeze"
          , button
                [ type_ "button"
                , onClick ToggleView
                ]
                [ text "Toggle View" ]
          , viewMesh model
          ]
        ]
        |> div []


viewSlider : Model -> List (Html Msg)
viewSlider model =
    case model.view of
        ColorWheelView ->
            [ p [] [ text "Value" ]
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
            [ p [] [ text "Hue" ]
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
            viewColorWheel model.wheelMeshes model.window model.theta (toValue model.value)

        HueGridView ->
            case model.hueMesh of
                Just mesh ->
                    viewHueGrid model.window model.theta mesh

                Nothing ->
                    p [] [ text "No mesh!" ]



---- VIEW ----


viewColorWheel : Dict Int AppMesh -> Window.Size -> Float -> Int -> Html msg
viewColorWheel meshes window theta value =
    let
        x =
            cos theta

        y =
            0 - sin theta

        w =
            toFloat window.width

        h =
            toFloat window.height
    in
        WebGL.toHtml
            [ width window.width
            , height window.height
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
                                    { perspective = perspective w h x y }
                                    :: acc

                            Nothing ->
                                acc
                    )
                    []
            )


viewHueGrid : Window.Size -> Float -> AppMesh -> Html Msg
viewHueGrid window theta mesh =
    let
        x =
            cos theta

        y =
            0 - sin theta

        w =
            toFloat window.width

        h =
            toFloat window.height
    in
        WebGL.toHtml
            [ width window.width
            , height window.height
            , style [ ( "display", "block" ) ]
            ]
            [ WebGL.entity
                vertexShader
                fragmentShader
                mesh
                { perspective = perspective w h x y }
            ]



---- CAMERA CONSTANTS ----


lookFrom : Float
lookFrom =
    6



---- CAMERA AND SHADERS ----


perspective : Float -> Float -> Float -> Float -> Mat4
perspective width height x y =
    let
        eye =
            vec3 x 0 y
                |> Vec3.normalize
                |> Vec3.scale 6
    in
        Mat4.mul
            (Mat4.makePerspective 30 (width / height) 0.01 100)
            (Mat4.makeLookAt eye (vec3 0 0 0) Vec3.j)


vertexShader : Shader Vertex Uniforms { vcolor : Vec3 }
vertexShader =
    [glsl|
        attribute vec3 position;
        attribute vec3 color;
        uniform mat4 perspective;
        varying vec3 vcolor;
        void main () {
            gl_Position = perspective * vec4(position, 1.0);
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
