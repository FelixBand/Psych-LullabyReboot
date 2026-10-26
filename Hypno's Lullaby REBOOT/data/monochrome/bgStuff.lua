-- background eyes & pulsing BG

-- ===== config =============================================================
local EYE_SCALE = 2 / 3

-- The eyes are ordinary camGame sprites: camGame's zoom and scroll affect them like anything else,
-- and each depth layer follows the camera by its own scroll factor (1 = with the world, 0 = pinned).
-- The three FIELD_ values move/scale the whole collection of eyes.
local FIELD_SCALE = 1.67   -- zoom of the whole field (eyes, spacing, bloom) about the screen centre. 1 = as authored
local FIELD_X = -420         -- pan the whole field in screen pixels (+ = right)
local FIELD_Y = -100         -- (+ = down)
local DEPTH_SCROLL = {[1] = 1.0, [2] = 1.0, [3] = 1.0}   -- depth 1 = far/small eyes, depth 3 = front/big eyes

-- ===== state ==============================================================
local bgUnowns = {}
-- Wobble phase is accumulated instead of computed as songTime * speed, so changing the speed
-- never makes the eyes teleport (songTime * 2 -> songTime * 0 used to jump them to phase 0).
local wobblePhase = 0
local lastSongTime = nil
local eyesBlackened = false

local eyeProgressTimes = {0, 91.541664, 91.833336, 92.66667, 93.083336, 151.9167, 232.41667, 232.5, 233.04167, 233.41667, 236.70834, 236.79167, 237.41667, 237.75002, 249.83336, 249.91669, 250.54169, 250.87503, 329.58334, 330.04166, 362.5417, 382.09}
local eyeProgressValues = {0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1}
local eyeProgressTransitions = {1, 0.5, 1, 0.5, 0, 0, 0.5, 1, 1, 1, 0.5, 1, 1, 1, 0.5, 1, 1, 1, 1, 1, 2, 1}
local eyeHoldTimes = {0, 151.91667, 232.41667, 233.04167, 233.41667, 236.70834, 236.95833, 237.33334, 237.70834, 249.83336, 250.08334, 250.45836, 250.83336, 265.625, 266.54166, 329.95834, 330.04166}
local eyeHoldValues = {0, 0, 0, 0, 0.5, 0.5, 1, 1, 0.75, 0.75, 1, 1, 1, 1, 0, 0, 1}
local eyeHoldTransitions = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5, 1, 1, 1}
local eyeStaggerTimes = {0, 91.541664, 232.375}
local eyeStaggerValues = {0.65, 0.561, 0.706}
local eyeVisibleTimes = {0, 91.541664, 92.958336, 151.91667, 205.375, 232.41667, 241, 242.08333, 266.54166, 330.04166}
local eyeVisibleValues = {false, true, false, true, false, true, false, true, false, true}
local eyeFadeEvents = {}
for _, times in ipairs({eyeProgressTimes, eyeHoldTimes, eyeStaggerTimes, eyeVisibleTimes}) do
    for _, time in ipairs(times) do
        if time > 0 then eyeFadeEvents[#eyeFadeEvents + 1] = time end
    end
end
table.sort(eyeFadeEvents)
for i = #eyeFadeEvents, 2, -1 do
    if math.abs(eyeFadeEvents[i] - eyeFadeEvents[i - 1]) < 0.001 then
        table.remove(eyeFadeEvents, i)
    end
end
local nextEyeFadeEvent = 1
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

-- ===== timeline helpers ===================================================
local function getTimelineValue(times, values, transitions, songTime, step)
    if songTime <= times[1] then return values[1] end
    for i = 1, #times - 1 do
        if songTime < times[i + 1] then
            if step then return values[i] end
            local t = math.max(0, math.min(1, (songTime - times[i]) / (times[i + 1] - times[i])))
            local transition = transitions and transitions[i] or 1
            if transition == 0 then
                t = 0
            elseif transition < 1 then
                t = 1 - (1 - t) ^ (1 / transition)
            else
                t = t ^ transition
            end
            return values[i] + (values[i + 1] - values[i]) * t
        end
    end
    return values[#values]
end

local function getEyeTimelineState(songTime)
    return {
        progress = getTimelineValue(eyeProgressTimes, eyeProgressValues, eyeProgressTransitions, songTime),
        holdProgress = getTimelineValue(eyeHoldTimes, eyeHoldValues, eyeHoldTransitions, songTime),
        staggerAmount = getTimelineValue(eyeStaggerTimes, eyeStaggerValues, nil, songTime, true),
        visible = getTimelineValue(eyeVisibleTimes, eyeVisibleValues, nil, songTime, true),
    }
end

local function getEyeAlphaAt(eyeIndex, state)
    if not state.visible then return 0 end
    local staggerIndex = (eyeIndex - 1) / math.max(#bgUnowns - 1, 1)

    local function staggeredProgress(value)
        local start = staggerIndex * state.staggerAmount
        local finish = start + (1 - state.staggerAmount)
        local t = math.max(0, math.min(1, (value - start) / (finish - start)))
        return t * t * (3 - 2 * t)
    end

    return math.max(staggeredProgress(state.progress), staggeredProgress(state.holdProgress))
end

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

    -- Pulse: the source retriggers one of three authored frame rates at exact song times.
    makeAnimatedLuaSprite('pulse', 'monochrome/pulse', -270, -270)
    addAnimationByIndices('pulse', 'pulse', 'pulse', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16', 24, false)
    addAnimationByIndices('pulse', 'pulse_quick', 'pulse', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16', 48, false)
    addAnimationByIndices('pulse', 'pulse_quicker', 'pulse', '4,5,6,7,8,9,10,11,12,13,14,15,16', 72, false)
    setScrollFactor('pulse', 0, 0)
    scaleObject('pulse', 1.1, 1.1)
    setProperty('pulse.alpha', 0)
    addLuaSprite('pulse', false)   -- added first, so it draws behind the eyes

    makeAnimatedLuaSprite('bgunownsfly', 'monochrome/unowns_bg_fly', -300, -300)
    addAnimationByPrefix('bgunownsfly', 'fly', 'unowns', 24, false)
    setProperty('bgunownsfly.color', getColorFromHex('FF0000'))
    addLuaSprite('bgunownsfly')

    for row in bgEyeData:gmatch("[^\n]+") do
        local values = {}
        for value in row:gmatch("[^,]+") do
            values[#values + 1] = tonumber(value)
        end

        local depth, x, y, width, height = values[1], values[2], values[3], values[4], values[5]
        local fill = eyeFill[values[10]] or 0.5
        local spriteWidth = width * EYE_SCALE * fill
        local spriteHeight = height * EYE_SCALE * fill
        local tag = "mono-bg-unown-" .. (#bgUnowns + 1)
        local bloomTag = tag .. "-bloom"

        makeLuaSprite(bloomTag, "monochrome/unown_particle_bloom", 0, 0)
        local sf = DEPTH_SCROLL[depth] or 0
        setScrollFactor(bloomTag, sf, sf)
        setProperty(bloomTag .. ".alpha", 0)
        addLuaSprite(bloomTag, false)

        makeLuaSprite(tag, "monochrome/unown_particle", 0, 0)
        scaleObject(tag, spriteWidth / 134, spriteHeight / 134)
        setScrollFactor(tag, sf, sf)
        setProperty(tag .. ".alpha", 0)
        addLuaSprite(tag, false)

        bgUnowns[#bgUnowns + 1] = {
            tag = tag,
            bloomTag = bloomTag,
            x = x * EYE_SCALE,
            y = y * EYE_SCALE,
            width = width * EYE_SCALE,
            height = height * EYE_SCALE,
            amount = values[6] * EYE_SCALE,
            speed = values[7] * 2,
            direction = math.rad(values[8]),
            side = values[9],
            fill = fill,
            variantScale = bloomVariantScale[values[10]] or 1.0,
            scrollFactor = sf,
        }
    end

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
local function fieldX(x) return screenWidth / 2 + (x - screenWidth / 2) * FIELD_SCALE + FIELD_X end
local function fieldY(y) return screenHeight / 2 + (y - screenHeight / 2) * FIELD_SCALE + FIELD_Y end

function onUpdate(elapsed)
    setShaderFloat('gameHUDblurController', 'blurWidth', getProperty('gameHUDblurController.x'))
    setShaderFloat('otherBlurController', 'blurWidth', getProperty('otherBlurController.x'))

    setProperty('pulse.scale.x', 2.5 - (getProperty('camGame.zoom') * 2))
    setProperty('pulse.scale.y', 2.5 - (getProperty('camGame.zoom') * 2))

    local songTime = getSongPosition() / 1000 + 1
    while nextPulseEvent <= #pulseEvents and pulseEvents[nextPulseEvent][1] <= songTime do
        playAnim('pulse', pulseEvents[nextPulseEvent][2], true)
        setProperty('pulse.alpha', 0.68235296)
        nextPulseEvent = nextPulseEvent + 1
    end

    if #bgUnowns == 0 then return end

    local k = FIELD_SCALE

    local movementSpeed = 1
    if songTime >= 366.54166 then
        movementSpeed = 0
    elseif songTime >= 232.375 then
        movementSpeed = 2
    end

    if lastSongTime == nil then
        wobblePhase = songTime
    else
        local dt = songTime - lastSongTime
        if dt > 0 and dt < 0.25 then wobblePhase = wobblePhase + dt * movementSpeed end
    end
    lastSongTime = songTime

    local shouldBlackenEyes = songTime >= 92.958336 and songTime < 231.272 or songTime >= 368.818
    if eyesBlackened ~= shouldBlackenEyes then
        for i = 1, #bgUnowns do
            setProperty(bgUnowns[i].tag .. '.color', shouldBlackenEyes and getColorFromHex('000000') or getColorFromHex('FFFFFF'))
        end
        eyesBlackened = shouldBlackenEyes
    end

    local eyeTimeline = getEyeTimelineState(songTime)
    while nextEyeFadeEvent <= #eyeFadeEvents and eyeFadeEvents[nextEyeFadeEvent] <= songTime do
        local eventTime = eyeFadeEvents[nextEyeFadeEvent]
        local beforeState = getEyeTimelineState(math.max(0, eventTime - 0.002))
        local afterState = getEyeTimelineState(eventTime + 0.002)
        for i = 1, #bgUnowns do
            local beforeAlpha = getEyeAlphaAt(i, beforeState)
            local targetAlpha = getEyeAlphaAt(i, afterState)
            if math.abs(targetAlpha - beforeAlpha) > 0.02 then
                local eye = bgUnowns[i]
                eye.alphaTweening = true
                doTweenAlpha('bgUnownFade-' .. i, eye.tag, targetAlpha, EYE_FADE_DURATION, 'sineInOut')
            end
        end
        nextEyeFadeEvent = nextEyeFadeEvent + 1
    end

    local intensity = 1
    if songTime >= 330.04166 then
        intensity = math.max(1, 15 - (14 * math.max(0, songTime - 330.04166) / (382.09 - 330.04166)))
    end

    for i = 1, #bgUnowns do
        local eye = bgUnowns[i]
        local alpha = getEyeAlphaAt(i, eyeTimeline)
        local time = wobblePhase * eye.speed
        local direction = eye.direction
        local side = eye.side
        local wobbleX = (math.cos(direction) * math.sin(time)) - (math.sin(direction) * math.cos(time * 0.85) * side)
        local wobbleY = (math.sin(direction) * math.sin(time)) + (math.cos(direction) * math.cos(time * 0.85) * side)
        local width = eye.width * eye.fill
        local height = eye.height * eye.fill

        local screenX = eye.x + ((eye.width - width) / 2) + (wobbleX * eye.amount * intensity)
        local screenY = eye.y + ((eye.height - height) / 2) + (wobbleY * eye.amount * intensity)
        local centerX = screenX + (width / 2)
        local centerY = screenY + (height / 2)

        setProperty(eye.tag .. '.x', fieldX(screenX))
        setProperty(eye.tag .. '.y', fieldY(screenY))
        scaleObject(eye.tag, width / 134 * k, height / 134 * k)
        if not eye.alphaTweening then
            setProperty(eye.tag .. '.alpha', alpha)
        end

        local bloomWidth = math.max(eye.width, eye.height) * 3 * eye.variantScale
        local bloomScale = bloomWidth / 1280
        local bloomHeight = 720 * (bloomWidth / 1280) * 0.44
        setProperty(eye.bloomTag .. '.x', fieldX(centerX - (bloomWidth / 2)))
        setProperty(eye.bloomTag .. '.y', fieldY(centerY - (bloomHeight * 0.85)))
        scaleObject(eye.bloomTag, bloomScale * k, bloomScale * 0.44 * k)
        setProperty(eye.bloomTag .. '.angle', math.deg(math.atan2(360 - centerY, 640 - centerX)))
        local renderedAlpha = getProperty(eye.tag .. '.alpha')
        setProperty(eye.bloomTag .. '.alpha', eyesBlackened and 0 or renderedAlpha)
    end
end

function onTweenCompleted(tag)
    local eyeIndex = tonumber(tag:match('^bgUnownFade%-(%d+)$'))
    if eyeIndex and bgUnowns[eyeIndex] then
        bgUnowns[eyeIndex].alphaTweening = false
    end
end