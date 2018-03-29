module Main exposing (..)

import AnimationFrame
import Html exposing (Html, div, p, text, input)
import Html.Attributes as HA exposing (type_, value, src, width, height, style, checked)
import Html.Events exposing (onClick, onInput)
import WebGL exposing (Mesh, Shader)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Time exposing (Time)
import MunsellData exposing (..)


---- WEBGL TYPES ----


type alias Color =
    Vec3


type alias Vertex =
    { position : Vec3
    , color : Color
    }


type alias Uniforms =
    { perspective : Mat4 }


{-| List of 4 corner points
-}
type alias Rectangle =
    List Vertex


{-| List of center point and 12 points on circumference
-}
type alias Circle =
    List Vertex



---- MODEL ----


{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { colors : MunsellData.ColorDict
    , value : String
    , frozen : Bool
    , theta : Float
    , mesh : Maybe (Mesh Vertex)
    }


init : ( Model, Cmd Msg )
init =
    let
        model =
            { colors = MunsellData.loadColors
            , value = "7"
            , frozen = True
            , theta = 0.5 * Basics.pi
            , mesh = Nothing
            }
    in
        update (ValueInput model.value) model



---- UPDATE ----


type Msg
    = FrameTick Time
    | ValueInput String
    | Freeze


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Freeze ->
            ( { model | frozen = not model.frozen }, Cmd.none )

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

        ValueInput newValue ->
            let
                model_ =
                    { model | value = newValue }
            in
                ( { model_ | mesh = buildMesh model_ }, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    List.concat
        [ [ p [] [ text "Value" ]
          , input
                [ type_ "range"
                , HA.min "1"
                , HA.max "9"
                , value model.value
                , onInput ValueInput
                ]
                []
          , p [] [ text "Freeze" ]
          , input
                [ type_ "checkbox"
                , checked model.frozen
                , onClick Freeze
                ]
                []
          ]
        , viewMesh model.theta model.mesh
        ]
        |> div []


viewMesh : Float -> Maybe (Mesh Vertex) -> List (Html Msg)
viewMesh theta m =
    case m of
        Just mesh ->
            [ WebGL.toHtml
                [ width 800
                , height 800
                , style [ ( "display", "block" ) ]
                ]
                [ WebGL.entity
                    vertexShader
                    fragmentShader
                    mesh
                    { perspective = perspective theta }
                ]
            ]

        Nothing ->
            []



---- WEBGL ----


circleRadius : Float
circleRadius =
    90.0


circlePoints : Int
circlePoints =
    30


bandUnit : Float
bandUnit =
    45.0


scaleFactor : Float
scaleFactor =
    circleRadius + 5.0 + (7.5 * bandUnit)


rectUnit : Float
rectUnit =
    40.0 / scaleFactor


{-| integers, 0 to 975
0 = 10RP
25 = 2.5R
50 = 5R
75 = 7.5R
100 = 10R
etc.
-}
hueRange : List Int
hueRange =
    List.range 0 39
        |> List.map (\i -> i * 25)


{-| even integers, 2 to 16
-}
chromaRange : List Int
chromaRange =
    List.range 1 8
        |> List.map (\i -> i * 2)


colorRect : Int -> Int -> Int -> ColorDict -> Maybe Color
colorRect hue value chroma d =
    case MunsellData.findColor hue value chroma d of
        Ok mc ->
            Just <| vec3 mc.red mc.green mc.blue

        Err err ->
            Nothing


xfRect : Int -> Int -> Int -> Mat4
xfRect hue _ chroma =
    let
        theta =
            (toFloat hue) * Basics.pi * (2.0 / 1000.0)

        band =
            toFloat (chroma // 2) - 0.5

        rad =
            (circleRadius + 5.0 + (band * bandUnit)) / scaleFactor
    in
        Mat4.identity
            |> rotate theta (vec3 0 0 1)
            |> translate (vec3 0 rad 0)


halfRect : Int -> Int -> Int -> ( Float, Float )
halfRect _ _ chroma =
    let
        dx2 =
            case chroma of
                2 ->
                    0.16 * rectUnit

                4 ->
                    0.25 * rectUnit

                6 ->
                    0.33 * rectUnit

                8 ->
                    0.4 * rectUnit

                10 ->
                    0.5 * rectUnit

                12 ->
                    0.5 * rectUnit

                _ ->
                    0.67 * rectUnit
    in
        ( dx2, 0.5 * rectUnit )


makeRect : Int -> Int -> Int -> ColorDict -> Maybe Rectangle
makeRect hue value chroma d =
    let
        c =
            colorRect hue value chroma d

        xf =
            xfRect hue value chroma

        ( dx2, dy2 ) =
            halfRect hue value chroma
    in
        case c of
            Just color ->
                Just <|
                    [ Vertex (transform xf (vec3 -dx2 -dy2 0)) color
                    , Vertex (transform xf (vec3 -dx2 dy2 0)) color
                    , Vertex (transform xf (vec3 dx2 dy2 0)) color
                    , Vertex (transform xf (vec3 dx2 -dy2 0)) color
                    ]

            Nothing ->
                Nothing


displayValue : Model -> Int
displayValue model =
    String.toInt model.value |> MunsellData.stringDefault 7



---- BUILDING RECTANGLES ----


makeRectsForHue : Int -> Int -> ColorDict -> List Rectangle
makeRectsForHue hue value d =
    List.foldl
        (\chroma acc ->
            case makeRect hue value chroma d of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


makeRects : Int -> ColorDict -> List Rectangle
makeRects value d =
    List.foldl (\hue acc -> (makeRectsForHue hue value d) ++ acc) [] hueRange


circumPoint : Color -> Int -> Vertex
circumPoint color i =
    let
        t =
            Basics.pi * toFloat i * (2.0 / toFloat circlePoints)

        ( x, y ) =
            ( sin t * circleRadius / scaleFactor, cos t * circleRadius / scaleFactor )
    in
        Vertex (vec3 x y 0) color


makeCircle : Int -> Circle
makeCircle value =
    let
        grayValue =
            (toFloat value) / 10.0

        color =
            vec3 grayValue grayValue grayValue

        circumf =
            List.range 1 circlePoints
                |> List.map (circumPoint color)
    in
        Vertex (vec3 0 0 0) color :: circumf


circleIndices : List ( Int, Int, Int )
circleIndices =
    List.range 1 circlePoints
        |> List.map
            (\i ->
                ( 0
                , i
                , if i < circlePoints then
                    i + 1
                  else
                    1
                )
            )


singleRectIndices : Int -> Int -> List ( Int, Int, Int )
singleRectIndices offset i =
    let
        base_i =
            4 * i + offset
    in
        [ ( base_i, base_i + 1, base_i + 2 ), ( base_i + 2, base_i + 3, base_i ) ]


rectIndices : Int -> List Rectangle -> List ( Int, Int, Int )
rectIndices offset rects =
    List.indexedMap (\i _ -> singleRectIndices offset i) rects
        |> List.concat


toMesh : Circle -> List Rectangle -> Mesh Vertex
toMesh circle rects =
    WebGL.indexedTriangles
        (List.concat (circle :: rects))
        (List.concat [ circleIndices, rectIndices (circlePoints + 1) rects ])


buildMesh : Model -> Maybe (Mesh Vertex)
buildMesh model =
    let
        value =
            displayValue model
    in
        case value > 0 && value <= 10 of
            True ->
                let
                    circle =
                        makeCircle value

                    rects =
                        makeRects value model.colors
                in
                    Just <| toMesh circle rects

            False ->
                Nothing


perspective : Float -> Mat4
perspective theta =
    Mat4.mul
        (Mat4.makePerspective 30 1 0.01 (100 * 10))
        (Mat4.makeLookAt (vec3 (4 * cos theta) 0 (4 * sin theta)) (vec3 0 0 0) (vec3 0 1 0))


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
        , subscriptions =
            (\model ->
                case model.frozen of
                    True ->
                        Sub.none

                    False ->
                        AnimationFrame.diffs FrameTick
            )
        }
