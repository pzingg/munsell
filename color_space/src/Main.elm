module Main exposing (..)

import Browser
import Browser.Events exposing (onAnimationFrameDelta,
  onMouseDown, onMouseMove, onMouseUp, onResize)
import ColorWheel
import Dict exposing (Dict)
import Geometry as Geom exposing (..)
import Html exposing (Html, div, p, text, label, input, button)
import Html.Attributes as HA exposing (type_, value, src, checked)
import Html.Events exposing (onClick, onInput)
import HueGrid
import Json.Decode as Decode exposing (Decoder)
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Munsell
    exposing
        ( MunsellColor
        , ColorDict
        , munsellHueName
        , findColor
        , loadColors
        )
import WebGL exposing (Mesh, Shader, Entity)


---- MODEL ----


type alias Flags = Int


type ColorView
    = ColorWheelView
    | HueGridView


type alias Rect a =
    { width : a
    , height : a
    }

type alias WindowSize = Rect Int

{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { windowRect : WindowSize
    , camera : Camera
    , lastDragPosition : Maybe Vec2
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
        ( { windowRect = { width = 800, height = 800 }
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
        -- Task.perform WindowResize Window.size
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


type Msg
    = FrameTick Float
    | ToggleView
    | ValueInput String
    | HueIndexInput String
    | AnimatingClick
    | ShowBallClick
    | ShowCoordinatesClick
    | Resize Float Float
    | MouseMove Float Float
    | MouseDown Float Float
    | MouseUp Float Float


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
                                    dt * dragRate * toFloat model.windowRect.width
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

        Resize newWidth newHeight ->
            ( { model | windowRect = { width = truncate newWidth, height = truncate newHeight }  }, Cmd.none )

        MouseDown x y ->
            -- Convert to element coordinates?
            ( { model | lastDragPosition = Just <| vec2 x y }, Cmd.none )

        MouseUp x y ->
            -- Convert to element coordinates?
            ( { model | lastDragPosition = Nothing }, Cmd.none )

        MouseMove x y ->
            -- Convert to element coordinates?
            case model.lastDragPosition of
                Just lastPosition ->
                    let
                        camera =
                            dragCamera
                                cameraDistance
                                (x - Vec2.getX lastPosition)
                                (y - Vec2.getY lastPosition)
                                model.camera
                    in
                        ( { model
                            | camera = camera
                            , lastDragPosition = Just <| vec2 x y
                          }
                        , Cmd.none
                        )

                Nothing ->
                    ( model, Cmd.none )



mousePosition : Decoder Msg
mousePosition =
    Decode.map2 MouseMove
        (Decode.field "pageX" Decode.float)
        (Decode.field "pageY" Decode.float)


mouseUp : Decoder Msg
mouseUp =
    Decode.map2 MouseUp
        (Decode.field "pageX" Decode.float)
        (Decode.field "pageY" Decode.float)


mouseDown : Decoder Msg
mouseDown =
    Decode.map2 MouseDown
        (Decode.field "pageX" Decode.float)
        (Decode.field "pageY" Decode.float)



---- VIEW ----


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
            [ viewMesh model ]
        , div
            [ HA.style "position" "absolute"
            , HA.style "z-index" "2"
            , HA.style "left" (String.fromInt (model.windowRect.width - toolboxWidth) ++ "px")
            , HA.style "top" "0px"
            , HA.style "width" (String.fromInt toolboxWidth ++ "px")
            , HA.style "text-align" "left"
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
                            String.fromFloat <| Vec2.getX pos

                        Nothing ->
                            ""
                    )
                ]
            , div []
                [ label [] [ text "Drag Pos Y " ]
                , text
                    (case model.lastDragPosition of
                        Just pos ->
                            String.fromFloat <| Vec2.getY pos

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
            [ HA.width windowRect.width
            , HA.height windowRect.height
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
            [ HA.width windowRect.width
            , HA.height windowRect.height
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
            [ onMouseMove mousePosition
            , onResize (\w h -> Resize (toFloat w) (toFloat h))
            ]
    in
        case model.animating of
            True ->
                Sub.batch [ onAnimationFrameDelta FrameTick, subAlways ]

            False ->
                subAlways
