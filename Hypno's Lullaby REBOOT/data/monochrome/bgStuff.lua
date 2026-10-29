-- this script handles all the fuckin background stuff.
-- Used the original .gd scripts for reference and man that shit's dense

-- ===== config =============================================================
local EYE_SCALE = 2 / 3

-- The eyes are ordinary camGame sprites: camGame's zoom and scroll affect them like anything else,
-- and each depth layer follows the camera by its own scroll factor (1 = with the world, 0 = pinned).
-- The three FIELD_ values move/scale the whole collection of eyes.
local FIELD_SCALE = 1.67   -- zoom of the whole field (eyes, spacing, bloom) about the screen centre. 1 = as authored
local FIELD_X = -420         -- pan the whole field in screen pixels (+ = right)
local FIELD_Y = -100         -- (+ = down)
local DEPTH_SCROLL = {[1] = 1.0, [2] = 1.0, [3] = 1.0} -- had a cool per layer parallaxing idea, but nah

-- ===== state ==============================================================
local bgUnowns = {}

-- The eyes no longer look anything up on a timeline every frame. The chart says WHEN something changes
-- (events.json, see the list below) and the script only does work while something is actually changing:
--   * the eye loop is skipped completely while all eyes are hidden, or shown but standing still
--   * eye alphas are only recomputed while a fade-in/out wave or an eye fade is running
--   * the bloom glow is not moved at all while the eyes are blackened (it is invisible then)
--
-- ===== chart events this script listens for ================================
--   Eyes Visible    1 / 0                  eyes may be shown / are hidden
--   Eyes Stagger    amount                 how far apart the eyes' fade-ins are spread (0 = all at once)
--   Eyes Progress   to  or  from,to        main fade wave.   value2 = duration,transition (leave empty = instant)
--   Eyes Hold       to  or  from,to        second wave.      value2 = duration,transition
--   Eyes Blacken    1 / 0                  eyes (and their glow) turn black / back to white
--   Eyes Motion     speed                  wobble speed multiplier (0 = standing still)
--   Eyes Intensity  from,to                wobble amount eases from "from" to "to".  value2 = duration in seconds
-- transition: 1 = linear, 0.5 = fast start / slow end (ease-out), 2 = slow start (ease-in)

local function newRamp(from, to, t0, dur, tr) return {from = from, to = to, t0 = t0, dur = dur, tr = tr} end
local state = {P = newRamp(0, 0, 0, 0, 1), H = newRamp(0, 0, 0, 0, 1), S = 0.65, V = false}
local prevState, pendingT = nil, nil   -- the moment currently being collected (several events can share one)
local pendingBlacken = nil
local alphaActive = false   -- true while a wave is running or an eye is fading, i.e. alphas can still change
local rampEnd = 0
local fadingCount = 0
local anyShown = false      -- at least one eye is visible (or still has a glow on screen)
local needPass = false      -- ask for one more run of the eye loop even though nothing is moving
local blackened = false

local speed, phaseBase, phaseT = 1, 0, 0       -- wobble phase = phaseBase + speed * (songTime - phaseT)
local intensity = {from = 1, to = 1, t0 = 0, dur = 0}
local intensityRamping, intensityEnd = false, 0

local pulseEventData = [[
152.00000p 153.62500r 153.83333r 154.04167r 154.25000r 154.45833r 154.66667r 154.87500r 155.08333r 155.29167r 155.50000r 155.70834r 155.91667r 156.12500r 156.33334r 156.54167r
156.75000r 156.95833r 157.16666r 157.37500r 157.58333r 157.79166r 158.00000r 158.20833r 158.41666r 158.62500r 158.83333r 159.04167r 159.25000r 159.45833r 159.66667r 159.87500r
160.08333r 160.29167r 160.50000r 160.70834r 160.91667r 161.12500r 161.33334r 161.54167r 161.75000r 161.95834r 162.37502r 162.58334r 162.79167r 163.00002r 163.20834r 163.41667r
163.62500r 163.83333r 164.04166r 164.25000r 164.45833r 164.66666r 164.87500r 165.08333r 165.29166r 165.50000r 165.70833r 165.91666r 166.12500r 166.33333r 166.54167r 166.75000r
166.95833r 167.16666r 167.37498r 167.58331r 167.79166r 167.99998r 168.20831r 168.41666r 168.62498r 168.83331r 169.04166r 169.24998r 169.45831r 169.66667r 169.87500r 170.08334r
170.29167r 170.50000r 170.70833r 170.91666r 171.12500p 175.50000p 177.73209r 177.95833r 178.20834r 178.45834r 178.68459r 178.91667r 179.16667r 179.39291r 179.62500r 179.83333p
188.70833p 195.16667q 195.66544q 196.16667q 199.54167p 200.58333p 201.66667p 202.70834p 203.79167p 204.87500p 205.91666p 207.00000p 208.12500p 209.20833p 210.33333p 211.37498p
212.45833p 213.50000p 214.75000r 214.95834r 215.16667r 215.37500r 215.58334r 215.79167r 216.00000r 223.62500p 224.66667p 225.75000p 226.83333p 227.93124p 229.04167p 230.12500p
231.50000q 231.75000q 232.04167q 233.37500p 237.87500q 238.20833r 238.41667r 238.91667q 239.25000r 239.45834r 239.95834q 240.29167r 240.50002r 241.91667p 243.04167p 244.12500p
245.29167p 246.41667p 247.54167p 248.83334r 249.00000r 249.20833r 249.41667r 249.58333p 251.31033p 253.54167r 253.75000r 253.91667r 254.04167p 255.08333p 256.12500p 257.25000p
258.33334p 259.45834p 260.58334p 261.70834p 266.04166p 331.08334q 331.66666q 332.29166q 332.87500q 333.45834q 334.04170q 334.62500q 335.79166q 336.37500q 336.91666q 337.45834q
338.04166q 338.62500q 339.20834q 339.79166q 340.37500q 340.95830q 341.54166q 342.12497q 342.74997q 344.37503q 344.95834q 345.54170q 346.12500q 346.70834q 348.62503r 348.83334r
349.04170r 349.25000r 349.45834r 349.66670r 349.87500r 350.08334r 350.29170r 350.50000r 350.70834r 350.91670r 351.12500r 351.33334r 351.54170r 351.75000r 351.95834r 352.16670r
352.37500r 352.58334r 352.79170r 353.00000r 353.20834r 353.41670r 353.62500r 353.83334r 354.04170r 354.25000r 354.45834r 354.66670r 354.87500r 355.08334r 355.29170r 355.50000r
355.70834r 355.91670r 356.12500r 356.54170r 356.95834r 357.16666r 357.37500r 357.79170r 358.00000r 358.20834r 358.41670r 358.62500r 358.83334r 359.04170r 359.25000r 359.45834r
359.66670r 359.87500r 360.08334r 360.29170r 360.50000r 360.70834r 360.91670r 361.12500r 361.33334r 361.54170r 361.75000r 361.95834r 362.16670r 362.37500r 362.58334r 362.79170r
363.00000r
]]
local pulseAnimations = {p = "pulse", q = "pulse_quick", r = "pulse_quicker"}
local pulseEvents = {}
for event in pulseEventData:gmatch("%S+") do
    local time, animation = event:match("^([%d%.]+)([pqr])$")
    pulseEvents[#pulseEvents + 1] = {tonumber(time), pulseAnimations[animation]}
end
local nextPulseEvent = 1

-- ===== helpers ============================================================
-- value of a ramp (from -> to over dur seconds starting at t0) at time t
local function rampAt(r, t)
    if t >= r.t0 + r.dur then return r.to end
    if t <= r.t0 then return r.from end
    local x = (t - r.t0) / r.dur
    local tr = r.tr
    if tr == 0 then
        x = 0
    elseif tr < 1 then
        x = 1 - (1 - x) ^ (1 / tr)
    else
        x = x ^ tr
    end
    return r.from + (r.to - r.from) * x
end

local function intensityAt(t)
    local r = intensity
    if r.dur <= 0 or t >= r.t0 + r.dur then return r.to end
    if t <= r.t0 then return r.from end
    return r.from + (r.to - r.from) * (t - r.t0) / r.dur
end

local function smooth01(x)
    if x < 0 then x = 0 elseif x > 1 then x = 1 end
    return x * x * (3 - 2 * x)
end

-- alpha of one eye for a given state (p / h = the two wave values at the moment in question)
local function alphaFor(eye, visible, stagger, p, h)
    if not visible then return 0 end
    local start = eye.staggerIndex * stagger
    local span = 1 - stagger
    local a = smooth01((p - start) / span)
    local b = smooth01((h - start) / span)
    return a > b and a or b
end

local function nums(s)   -- "0,1" -> {0, 1}
    local out = {}
    if s ~= nil then
        for x in tostring(s):gmatch('[^,%s]+') do out[#out + 1] = tonumber(x) end
    end
    return out
end

local function makeRamp(value1, value2, t0)
    local v, d = nums(value1), nums(value2)
    local from = v[1] or 0
    local to = v[2] or from            -- a single number = jump straight to it
    return newRamp(from, to, t0, d[1] or 0, d[2] or 1)
end

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- ===== eye data ===========================================================
-- Authored Monochrome background eyes: depth, rect x/y/size, wobble amount/speed/angle/side, eye variant.
local bgEyeData = [[1,540.698,540.680,78.082,78.087,12.445,0.361,349.710,0.409,0
1,1823.830,104.929,54.046,54.038,14.706,0.720,292.796,0.254,0
1,435.888,515.646,49.263,49.228,5.667,0.433,251.367,0.194,0
1,733.829,585.286,45.701,45.700,5.762,0.468,80.888,0.282,0
1,1078.083,1000.126,43.733,43.812,11.227,0.486,186.656,0.421,0
1,1831.562,278.714,55.008,55.016,5.577,0.633,122.210,0.637,0
1,275.183,969.777,78.729,78.657,7.890,0.476,2.655,0.335,0
1,443.646,516.790,62.000,61.970,17.969,0.698,206.242,0.630,0
1,1223.923,765.825,55.716,55.717,6.215,0.671,101.173,0.301,0
1,1814.195,515.087,65.453,65.232,9.636,0.339,335.192,0.614,0
1,1402.834,403.451,49.631,49.626,9.934,0.635,263.978,0.638,0
1,847.099,802.077,53.865,53.864,10.110,0.612,64.397,0.161,0
1,1301.911,2.087,55.868,55.862,17.647,0.330,306.230,0.299,0
1,486.762,689.359,42.999,43.009,12.087,0.250,253.199,0.625,0
1,120.672,6.567,69.046,69.052,11.374,0.597,284.668,0.405,0
1,1395.066,405.317,68.240,68.241,13.724,0.465,69.115,0.277,0
1,975.182,298.588,48.291,47.911,8.175,0.313,216.889,0.566,0
1,1183.879,47.034,50.110,50.106,5.380,0.178,273.283,0.157,0
1,1182.341,569.524,65.685,65.795,11.879,0.527,345.991,0.582,0
1,285.981,239.419,52.680,52.679,10.233,0.216,83.343,0.420,0
1,1678.275,792.135,66.440,66.449,16.679,0.606,176.728,0.000,0
1,265.188,348.224,51.907,51.902,10.376,0.692,29.624,0.228,0
1,214.751,530.994,76.887,76.403,8.900,0.290,63.774,0.366,0
1,560.197,658.313,74.295,74.289,4.654,0.171,353.874,0.474,0
1,1503.495,1035.579,67.312,67.412,8.105,0.677,79.273,0.409,0
1,1616.416,675.594,63.199,63.199,7.527,0.588,207.671,0.616,0
1,196.229,796.249,58.788,58.794,16.369,0.581,349.420,0.472,0
1,937.528,277.342,43.588,43.588,15.938,0.531,181.699,0.299,0
1,871.999,256.893,62.986,62.993,14.871,0.453,343.805,0.241,0
1,1350.398,230.519,55.969,55.975,14.058,0.419,186.389,0.256,0
1,1604.406,852.507,62.003,62.003,14.434,0.737,121.037,0.634,0
1,859.664,707.481,71.620,71.622,8.777,0.253,240.253,0.325,0
1,774.817,33.103,69.570,69.572,4.349,0.569,334.882,0.510,0
1,254.185,204.370,73.638,73.752,12.566,0.238,179.805,0.637,0
1,1731.716,912.308,53.359,53.357,11.675,0.553,131.679,0.296,0
1,1740.847,182.401,55.093,55.080,16.412,0.501,2.199,0.254,0
1,188.652,184.446,56.112,56.135,16.772,0.336,106.805,0.647,0
1,633.665,919.020,60.019,60.020,8.693,0.298,245.225,0.490,0
1,708.023,830.346,45.138,45.120,14.759,0.689,122.176,0.199,0
1,701.762,411.441,57.195,57.149,4.788,0.545,186.277,0.375,0
1,1882.405,858.482,51.683,51.684,13.261,0.741,130.354,0.522,0
1,1383.664,686.497,79.122,79.120,6.139,0.698,119.890,0.181,0
1,478.077,722.745,71.192,71.235,15.081,0.701,42.085,0.462,0
1,330.093,590.438,75.344,75.341,5.042,0.151,169.084,0.604,0
1,649.923,686.523,72.347,72.347,4.938,0.276,116.837,0.152,0
1,1820.398,373.190,77.960,77.972,14.313,0.301,86.258,0.370,0
1,591.491,1029.762,55.231,55.158,14.759,0.737,267.784,0.466,0
1,1488.660,640.568,74.953,74.954,13.534,0.352,276.078,0.154,0
1,664.296,162.653,61.876,61.946,14.966,0.186,321.308,0.573,0
1,1577.567,937.956,49.939,49.940,10.553,0.466,30.402,0.306,0
1,1114.169,598.072,43.201,43.238,10.582,0.454,101.286,0.184,0
1,1739.965,97.712,57.974,57.972,15.949,0.326,169.681,0.390,0
1,1550.320,413.673,72.548,72.513,11.252,0.643,313.222,0.558,0
1,335.583,866.974,52.951,52.955,6.427,0.571,200.859,0.582,0
1,1527.611,328.678,66.329,66.317,11.735,0.165,111.285,0.409,0
1,29.368,904.308,52.496,52.494,14.287,0.733,147.285,0.455,0
1,372.996,476.343,73.284,73.323,9.714,0.305,51.942,0.248,0
1,174.306,259.231,51.401,51.365,7.427,0.165,133.965,0.252,0
1,766.305,643.095,71.068,71.068,10.685,0.619,245.156,0.527,0
1,1707.178,756.154,50.549,50.549,13.014,0.508,17.974,0.215,0
1,62.680,505.299,66.760,66.672,5.860,0.296,218.373,0.400,0
1,963.483,900.348,58.112,58.078,16.104,0.275,78.583,0.449,0
1,1361.842,1002.788,42.727,42.763,9.524,0.627,241.870,0.397,0
1,278.219,715.875,59.199,59.203,6.283,0.284,202.665,0.354,0
1,1032.765,315.803,77.197,77.288,13.042,0.222,70.312,0.429,0
1,943.013,332.740,47.835,47.856,8.971,0.669,36.611,0.483,0
1,1836.342,319.767,59.931,59.930,4.329,0.465,36.402,0.526,0
1,1395.603,768.987,58.033,58.034,4.075,0.517,36.397,0.447,0
1,1511.499,808.462,65.390,65.393,11.049,0.537,290.416,0.384,0
2,72.251,742.464,78.325,78.329,11.730,0.266,65.037,0.328,1
2,280.332,414.650,66.679,66.709,16.376,0.342,339.182,0.294,1
2,1762.309,680.684,76.421,76.421,14.941,0.649,108.394,0.262,1
2,1155.091,891.021,71.447,71.507,14.283,0.156,96.375,0.376,1
2,409.846,65.767,43.952,43.951,10.235,0.365,304.293,0.343,1
2,479.137,133.920,78.625,78.578,7.694,0.501,192.839,0.359,1
2,633.169,500.643,73.462,73.490,10.056,0.504,200.257,0.294,1
2,1452.063,723.396,69.188,69.191,7.114,0.702,180.940,0.562,1
2,620.171,1026.312,43.473,43.488,11.453,0.340,139.372,0.575,1
2,578.028,894.176,73.176,73.176,16.523,0.191,110.389,0.587,1
2,840.307,600.670,73.349,73.341,6.354,0.633,33.725,0.211,1
2,1343.938,868.861,68.948,68.948,5.015,0.497,208.746,0.362,1
2,635.007,103.385,71.436,71.456,8.767,0.262,290.770,0.566,1
2,788.345,507.195,47.364,47.356,12.903,0.725,298.307,0.409,1
2,1350.277,59.350,62.989,62.973,9.726,0.364,249.526,0.508,1
2,1315.169,371.092,74.332,74.329,10.253,0.699,289.378,0.236,1
2,966.463,97.141,62.450,62.429,10.225,0.554,193.792,0.171,1
2,74.232,406.149,61.959,61.971,11.982,0.314,164.121,0.283,1
2,1261.289,828.021,44.482,44.483,4.021,0.700,251.224,0.409,1
2,1841.550,725.865,49.561,49.563,12.833,0.508,305.701,0.555,1
2,1621.779,275.100,53.636,53.668,14.226,0.524,271.775,0.508,1
2,531.159,377.381,48.301,48.260,7.326,0.368,4.575,0.493,1
2,1576.924,576.361,64.526,64.526,12.996,0.700,87.804,0.433,1
2,1655.488,978.600,71.585,71.394,9.882,0.589,202.647,0.503,1
2,116.224,590.879,74.427,74.425,7.898,0.501,297.680,0.573,1
2,1672.879,399.847,58.434,58.434,7.676,0.522,234.915,0.610,1
2,1128.145,744.203,55.210,55.248,7.071,0.580,153.011,0.625,1
2,1822.843,528.236,53.400,53.435,14.158,0.544,353.388,0.578,1
2,895.739,524.842,60.891,60.938,17.278,0.438,167.991,0.642,1
2,1145.140,771.504,73.793,73.779,16.948,0.521,11.366,0.500,1
2,1170.506,351.361,61.974,61.978,17.819,0.201,67.984,0.306,1
2,443.012,857.969,67.651,67.308,5.915,0.388,34.305,0.220,1
2,1323.762,1049.340,79.578,79.287,9.519,0.282,118.249,0.563,1
2,1494.824,74.564,60.141,60.136,15.393,0.741,121.508,0.390,1
2,561.787,66.166,42.620,42.613,12.835,0.744,24.673,0.406,1
2,813.361,391.295,58.702,58.573,5.428,0.253,253.218,0.376,1
2,1015.733,402.433,69.576,69.479,12.373,0.696,127.315,0.228,1
2,242.173,431.683,72.255,72.439,14.901,0.402,357.168,0.207,1
2,1149.485,167.002,76.975,76.824,14.686,0.370,75.888,0.406,1
2,1056.815,725.694,49.078,49.120,10.937,0.384,87.240,0.318,1
2,272.723,56.264,49.093,49.122,16.307,0.452,203.084,0.240,1
3,948.244,197.451,58.226,58.226,17.921,0.405,70.216,0.470,2
3,1591.328,148.829,60.549,60.548,7.635,0.249,159.668,0.524,2
3,1743.202,21.742,51.169,51.167,5.657,0.306,87.878,0.369,2
3,706.362,280.853,68.629,68.628,5.625,0.698,355.087,0.508,2
3,1228.887,1013.010,57.488,57.478,9.049,0.385,202.919,0.293,2
3,143.212,966.336,54.481,54.804,4.597,0.741,225.814,0.257,2
3,1452.218,544.483,50.945,50.944,16.782,0.588,163.964,0.488,2
3,1048.379,579.947,55.947,55.696,8.468,0.746,51.535,0.266,2
3,1669.536,470.910,62.135,62.121,10.787,0.334,359.887,0.573,2
3,457.611,251.965,76.310,76.297,15.532,0.316,43.025,0.615,2
3,1268.340,245.837,48.735,48.730,14.809,0.341,200.136,0.255,2
3,447.925,978.279,52.548,52.518,11.687,0.653,343.086,0.255,2
3,90.487,305.186,46.584,46.580,16.165,0.389,18.565,0.312,2
3,1823.980,522.215,41.913,41.972,16.406,0.400,298.157,0.205,2
3,1044.071,863.755,46.059,46.013,8.357,0.510,327.537,0.398,2
3,828.238,1009.667,54.522,54.662,8.530,0.240,96.747,0.167,2
3,33.128,93.462,76.154,76.157,15.376,0.589,301.010,0.332,2]]

local eyeFill = {[0] = 0.18, [1] = 0.38, [2] = 1.0}
local bloomVariantScale = {[0] = 0.395, [1] = 0.65, [2] = 1.325}
local EYE_FADE_DURATION = 0.18

function onCreate()
    bgUnowns = {}

    makeAnimatedLuaSprite('kingseye', 'monochrome/kingseye', -570, -275)
    addAnimationByIndices('kingseye', 'closed', 'open', '0', 1, false)
    addAnimationByPrefix('kingseye', 'open', 'open', 8, false)
    --setScrollFactor('kingseye', 0, 0)
    scaleObject('kingseye', 1.58, 1.58)
    setProperty('kingseye.alpha', 0.0001)
    --setProperty('kingseye.color', getColorFromHex('FFD4BD'))
    addLuaSprite('kingseye')
    playAnim('kingseye', 'closed', true)

    -- makeLuaSprite('kingseyebloom', 'monochrome/unown_particle_bloom', -450, -450)
    -- setScrollFactor('kingseyebloom', 0, 0)
    -- scaleObject('kingseyebloom', 2, 1.5)
    -- setProperty('kingseyebloom.alpha', 0.5)
    -- addLuaSprite('kingseyebloom')

    -- Pulse: the source retriggers one of three authored frame rates at exact song times.
    makeAnimatedLuaSprite('pulse', 'monochrome/pulse', -270, -270)
    addAnimationByIndices('pulse', 'pulse', 'pulse', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16', 24, false)
    addAnimationByIndices('pulse', 'pulse_quick', 'pulse', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16', 48, false)
    addAnimationByIndices('pulse', 'pulse_quicker', 'pulse', '4,5,6,7,8,9,10,11,12,13,14,15,16', 72, false)
    setScrollFactor('pulse', 0, 0)
    scaleObject('pulse', 1.1, 1.1)
    setProperty('pulse.alpha', 0)
    addLuaSprite('pulse', false)   -- added first, so it draws behind the eyes


    for row in bgEyeData:gmatch("[^\n]+") do
        local values = {}
        for value in row:gmatch("[^,]+") do
            values[#values + 1] = tonumber(value)
        end

        local depth, x, y, width, height = values[1], values[2], values[3], values[4], values[5]
        local fill = eyeFill[values[10]] or 0.5
        local tag = "mono-bg-unown-" .. (#bgUnowns + 1)
        local bloomTag = tag .. "-bloom"
        local sf = DEPTH_SCROLL[depth] or 0

        makeLuaSprite(bloomTag, "monochrome/unown_particle_bloom", 0, 0)
        setScrollFactor(bloomTag, sf, sf)
        setProperty(bloomTag .. ".alpha", 0)
        addLuaSprite(bloomTag, false)

        makeLuaSprite(tag, "monochrome/unown_particle", 0, 0)
        setScrollFactor(tag, sf, sf)
        setProperty(tag .. ".alpha", 0)
        addLuaSprite(tag, false)

        local w, h = width * EYE_SCALE, height * EYE_SCALE
        local variantScale = bloomVariantScale[values[10]] or 1.0
        local bloomWidth = math.max(w, h) * 3 * variantScale
        local bloomScale = bloomWidth / 1280
        local bloomHeight = 720 * bloomScale * 0.44

        -- Sizes never change, so they are applied once here instead of every frame.
        scaleObject(tag, w * fill / 134 * FIELD_SCALE, h * fill / 134 * FIELD_SCALE)
        scaleObject(bloomTag, bloomScale * FIELD_SCALE, bloomScale * 0.44 * FIELD_SCALE)

        bgUnowns[#bgUnowns + 1] = {
            tag = tag,
            bloomTag = bloomTag,
            -- property names built once (they used to be concatenated ~10x per eye per frame)
            px = tag .. '.x', py = tag .. '.y', pa = tag .. '.alpha', pc = tag .. '.color',
            bx = bloomTag .. '.x', by = bloomTag .. '.y', ba = bloomTag .. '.alpha', bang = bloomTag .. '.angle',
            x = x * EYE_SCALE,
            y = y * EYE_SCALE,
            width = w,
            height = h,
            amount = values[6] * EYE_SCALE,
            speed = values[7] * 2,
            cosD = math.cos(math.rad(values[8])),
            sinD = math.sin(math.rad(values[8])),
            side = values[9],
            fill = fill,
            bloomHalfW = bloomWidth / 2,
            bloomOffY = bloomHeight * 0.85,
            -- constant parts of the position
            baseX = x * EYE_SCALE + (w - w * fill) / 2,
            baseY = y * EYE_SCALE + (h - h * fill) / 2,
            halfW = w * fill / 2,
            halfH = h * fill / 2,
            scrollFactor = sf,
            -- state
            alpha = 0, shownAlpha = 0, shownBloom = 0,
            fading = false, fadeT = 0, fadeFrom = 0, fadeTo = 0,
            lastX = nil, lastY = nil, lastAngle = nil,
            bloomStale = true,
        }
    end
    for i = 1, #bgUnowns do
        bgUnowns[i].staggerIndex = (i - 1) / math.max(#bgUnowns - 1, 1)
    end

    makeAnimatedLuaSprite('bgunownsfly', 'monochrome/unowns_bg_fly', -300, -300)
    addAnimationByPrefix('bgunownsfly', 'fly', 'unowns', 24, false)
    setProperty('bgunownsfly.color', getColorFromHex('FF0000'))
    addLuaSprite('bgunownsfly')

    if shadersEnabled then
        makeLuaSprite('gameHUDblurController', '', 0, 0)
        makeLuaSprite('otherBlurController', '', 0, 0)

        initLuaShader('zoomBlur')

        runHaxeCode([[
            var blurShaderGameHUD = game.createRuntimeShader('zoomBlur');

            game.getLuaObject('gameHUDblurController').shader = blurShaderGameHUD;

            var blurShaderOther = game.createRuntimeShader('zoomBlur');

            game.getLuaObject('otherBlurController').shader = blurShaderOther;

            game.camGame.setFilters([
                new ShaderFilter(blurShaderGameHUD),
            ]);
            game.camHUD.setFilters([
                new ShaderFilter(blurShaderGameHUD),
            ]);
            game.camOther.setFilters([
                new ShaderFilter(blurShaderOther),
            ]);
        ]]);

        setShaderFloat('gameHUDblurController', 'sampleCount', 13)
        setShaderFloat('otherBlurController', 'sampleCount', 13)
    end
end

-- Where an authored position (1280x720 space) ends up after FIELD_SCALE / FIELD_X / FIELD_Y.
local fieldOffX = screenWidth / 2 * (1 - FIELD_SCALE) + FIELD_X
local fieldOffY = screenHeight / 2 * (1 - FIELD_SCALE) + FIELD_Y

local lastBlurGameHUD, lastBlurOther, lastZoom = nil, nil, nil
local PI = math.pi

-- ===== event handling =====================================================
-- A "moment" is one chart time. Several events can share it (e.g. Visible + Progress + Stagger when the eyes
-- appear), so their changes are collected first and handled together on the next frame (processKey).
-- At that moment every eye whose alpha JUMPS by more than 0.02 gets a short 0.18s sineInOut fade instead of
-- popping, exactly like before; everything else follows the waves.
local function processKey()
    local T = pendingT
    local before, after = prevState, state
    local tb = T - 0.002
    if tb < 0 then tb = 0 end
    local ta = T + 0.002
    local pb, hb = rampAt(before.P, tb), rampAt(before.H, tb)
    local pa, ha = rampAt(after.P, ta), rampAt(after.H, ta)
    for i = 1, #bgUnowns do
        local eye = bgUnowns[i]
        local beforeAlpha = alphaFor(eye, before.V, before.S, pb, hb)
        local targetAlpha = alphaFor(eye, after.V, after.S, pa, ha)
        if math.abs(targetAlpha - beforeAlpha) > 0.02 then
            if not eye.fading then fadingCount = fadingCount + 1 end
            eye.fading = true
            eye.fadeT = 0
            eye.fadeFrom = eye.alpha
            eye.fadeTo = targetAlpha
        end
    end
    pendingT, prevState = nil, nil
    alphaActive = true
    local e1 = after.P.t0 + after.P.dur
    local e2 = after.H.t0 + after.H.dur
    rampEnd = e1 > e2 and e1 or e2
end

local function beginMoment(T)
    if pendingT ~= nil and math.abs(T - pendingT) > 0.0001 then processKey() end   -- a different moment: finish the old one
    if pendingT == nil then
        prevState = {P = state.P, H = state.H, S = state.S, V = state.V}
        pendingT = T
    end
end

local function eventTime(strumTime)
    local ms = tonumber(strumTime)
    if ms == nil then ms = getSongPosition() end
    return ms / 1000 + 1   -- the same clock the eye data was authored in
end

local function applyBlacken(black)
    if black == blackened then return end
    blackened = black
    local color = getColorFromHex(black and '000000' or 'FFFFFF')
    for i = 1, #bgUnowns do
        local eye = bgUnowns[i]
        setProperty(eye.pc, color)
        if not black then eye.bloomStale = true end   -- the glow stood still while it was hidden
    end
    needPass = true
end

function onEvent(name, value1, value2, strumTime)
    if name == 'Eyes Visible' then
        beginMoment(eventTime(strumTime))
        state.V = (tonumber(value1) or 0) ~= 0
    elseif name == 'Eyes Stagger' then
        beginMoment(eventTime(strumTime))
        state.S = tonumber(value1) or state.S
    elseif name == 'Eyes Progress' then
        local T = eventTime(strumTime)
        beginMoment(T)
        state.P = makeRamp(value1, value2, T)
    elseif name == 'Eyes Hold' then
        local T = eventTime(strumTime)
        beginMoment(T)
        state.H = makeRamp(value1, value2, T)
    elseif name == 'Eyes Blacken' then
        pendingBlacken = (tonumber(value1) or 0) ~= 0
    elseif name == 'Eyes Motion' then
        local T = eventTime(strumTime)
        phaseBase = phaseBase + speed * (T - phaseT)   -- keep the wobble phase continuous across the speed change
        phaseT = T
        speed = tonumber(value1) or speed
        needPass = true
    elseif name == 'Eyes Intensity' then
        local T = eventTime(strumTime)
        local v, dur = nums(value1), tonumber(value2) or 0
        local from = v[1] or 1
        intensity = {from = from, to = v[2] or from, t0 = T, dur = dur}
        intensityRamping = dur > 0
        intensityEnd = T + dur
        needPass = true
    end
end

-- ===== per frame ==========================================================
function onUpdate(elapsed)
    -- blur: only touch the shaders when their value actually changed (and never when shaders are off)
    if shadersEnabled then
        local b1 = getProperty('gameHUDblurController.x')
        if b1 ~= lastBlurGameHUD then
            lastBlurGameHUD = b1
            setShaderFloat('gameHUDblurController', 'blurWidth', b1)
        end
        local b2 = getProperty('otherBlurController.x')
        if b2 ~= lastBlurOther then
            lastBlurOther = b2
            setShaderFloat('otherBlurController', 'blurWidth', b2)
        end
    end

    local zoom = getProperty('camGame.zoom')
    if zoom ~= lastZoom then
        lastZoom = zoom
        local s = 2.5 - (zoom * 2)
        setProperty('pulse.scale.x', s)
        setProperty('pulse.scale.y', s)
    end

    local songTime = getSongPosition() / 1000 + 1
    while nextPulseEvent <= #pulseEvents and pulseEvents[nextPulseEvent][1] <= songTime do
        playAnim('pulse', pulseEvents[nextPulseEvent][2], true)
        setProperty('pulse.alpha', 0.68235296)
        nextPulseEvent = nextPulseEvent + 1
    end

    local count = #bgUnowns
    if count == 0 then return end

    -- hand over what the chart events asked for since last frame
    if pendingBlacken ~= nil then
        local b = pendingBlacken
        pendingBlacken = nil
        applyBlacken(b)
    end
    if pendingT ~= nil then processKey() end
    if intensityRamping and songTime >= intensityEnd then
        intensityRamping = false
        needPass = true   -- one last pass at the final wobble amount
    end

    -- nothing to do: all eyes hidden, or shown but standing still, and no wave / fade / change pending
    local doAlpha = alphaActive
    if not (doAlpha or needPass or (anyShown and (speed ~= 0 or intensityRamping))) then return end
    needPass = false

    local fadingAtStart = fadingCount > 0
    local visible, stagger = state.V, state.S
    local pv, hv = 0, 0
    if doAlpha then
        pv = rampAt(state.P, songTime)
        hv = rampAt(state.H, songTime)
    end
    local phase = phaseBase + speed * (songTime - phaseT)
    local amtScale = intensityAt(songTime)
    local blk = blackened
    local shown = false

    for i = 1, count do
        local eye = bgUnowns[i]

        -- while an eye is fading, its bloom follows the eye's alpha from the previous frame (as before)
        local previousAlpha = eye.alpha
        local wasFading = eye.fading
        local alpha = previousAlpha
        if doAlpha then
            if eye.fading then
                eye.fadeT = eye.fadeT + elapsed
                local t = eye.fadeT / EYE_FADE_DURATION
                if t >= 1 then
                    eye.fading = false
                    fadingCount = fadingCount - 1
                    alpha = eye.fadeTo
                else
                    alpha = eye.fadeFrom + (eye.fadeTo - eye.fadeFrom) * (0.5 - math.cos(PI * t) / 2)
                end
            else
                alpha = alphaFor(eye, visible, stagger, pv, hv)
            end
            eye.alpha = alpha
        end

        -- completely invisible and already applied as invisible: nothing to move or draw
        if alpha ~= 0 or eye.shownAlpha ~= 0 or eye.shownBloom ~= 0 then
            shown = true
            local time = phase * eye.speed
            local sinT, cosT = math.sin(time), math.cos(time * 0.85) * eye.side
            local wobbleX = eye.cosD * sinT - eye.sinD * cosT
            local wobbleY = eye.sinD * sinT + eye.cosD * cosT
            local amt = eye.amount * amtScale

            local screenX = eye.baseX + wobbleX * amt
            local screenY = eye.baseY + wobbleY * amt

            local sx = screenX * FIELD_SCALE + fieldOffX
            local sy = screenY * FIELD_SCALE + fieldOffY
            local moved = false
            if sx ~= eye.lastX then eye.lastX = sx; setProperty(eye.px, sx); moved = true end
            if sy ~= eye.lastY then eye.lastY = sy; setProperty(eye.py, sy); moved = true end

            if alpha ~= eye.shownAlpha then
                eye.shownAlpha = alpha
                setProperty(eye.pa, alpha)
            end

            -- the glow only follows the eye when it actually moved, and not at all while the eyes are black
            if blk then
                if moved then eye.bloomStale = true end
            elseif moved or eye.bloomStale then
                eye.bloomStale = false
                local centerX = screenX + eye.halfW
                local centerY = screenY + eye.halfH
                setProperty(eye.bx, (centerX - eye.bloomHalfW) * FIELD_SCALE + fieldOffX)
                setProperty(eye.by, (centerY - eye.bloomOffY) * FIELD_SCALE + fieldOffY)
                local angle = math.deg(atan2(360 - centerY, 640 - centerX))
                if angle ~= eye.lastAngle then eye.lastAngle = angle; setProperty(eye.bang, angle) end
            end

            local bloomAlpha = blk and 0 or (wasFading and previousAlpha or alpha)
            if bloomAlpha ~= eye.shownBloom then
                eye.shownBloom = bloomAlpha
                setProperty(eye.ba, bloomAlpha)
            end
        end
    end
    anyShown = shown

    -- waves are over and every eye has settled on its timeline value: stop recomputing alphas
    if doAlpha and not fadingAtStart and songTime >= rampEnd then alphaActive = false end
end
