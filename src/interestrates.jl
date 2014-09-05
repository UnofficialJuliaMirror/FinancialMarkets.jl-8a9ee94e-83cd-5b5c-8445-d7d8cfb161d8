####
# Types
####

type InterestRate
    rate::Real
    compounding::Int
    daycount::DayCountFraction
    function InterestRate(rate, compounding, daycount)
        haskey(COMPOUNDINGS, compounding) || error("Invalid compounding.")
        new(rate, compounding, daycount)
    end
end


type DiscountFactor
    discountfactor::Real
    startdate::TimeType
    enddate::TimeType
    function DiscountFactor(discountfactor, startdate, enddate)
        startdate <= enddate || error("Start occurs after the end date.")
        new(discountfactor, startdate, enddate)
    end
end


####
# Methods
####

# IO
function Base.string(r::InterestRate)
    (@sprintf("%05f", 100 * r.rate) * "%," *
        uppercase(COMPOUNDINGS[r.compounding]) *
        "," * string(r.daycount))
end
Base.show(io::IO, r::InterestRate) = print(io, string(r))

# conversions
function Base.convert(::Type{DiscountFactor}, x::InterestRate, startdate::TimeType,
    enddate::TimeType)
    t = years(startdate, enddate, x.daycount)
    if x.compounding == Continuously
        df = exp(-x.rate * t)
    elseif x.compounding == Simply
        df = 1 / (1 + t * x.rate)
    else
        df = 1 / ((1 + x.rate / x.compounding) ^ (x.compounding * t))
    end
    return DiscountFactor(df, startdate, enddate)
end

function Base.convert(::Type{InterestRate}, x::DiscountFactor, compounding::Int,
    daycount::DayCountFraction)
    t = years(x.startdate, x.enddate, daycount)
    if compounding == Continuously
        rate = -log(x.discountfactor) / t
    elseif compounding == Simply
        rate = (1 / x.discountfactor - 1) / t
    else
        rate = (compounding *
            ((1 / x.discountfactor) ^ (1 / (compounding * t)) - 1))
    end
    return InterestRate(rate, compounding, daycount)
end

function Base.convert(::Type{InterestRate}, x::InterestRate, compounding::Int)
    startdate, enddate = (Date(2013, 1, 1), Date(2014, 1, 1))
    df = convert(DiscountFactor, x, startdate, enddate)
    convert(InterestRate, df, compounding, x.daycount)
end

function Base.convert(::Type{InterestRate}, x::InterestRate, daycount::DayCountFraction)
    startdate, enddate = (Date(2013, 1, 1), Date(2014, 1, 1))
    df = convert(DiscountFactor, x, startdate, enddate)
    convert(InterestRate, df, x.compounding, daycount)
end

function Base.convert(::Type{InterestRate}, x::InterestRate, compounding::Int,
    daycount::DayCountFraction)
    startdate, enddate = (Date(2013, 1, 1), Date(2014, 1, 1))
    df = convert(DiscountFactor, x, startdate, enddate)
    convert(InterestRate, df, compounding, daycount)
end

function equivalent(to::InterestRate, x::InterestRate)
    flag = !(x.compounding == to.compounding && x.daycount == to.daycount)
    flag ? convert(InterestRate, x, to.compounding, to.daycount) : x
end

# arithmetic operations
for op in (:+, :*, :-, :/)
    @eval begin
        function ($op)(x::InterestRate, y::Real)
            InterestRate(($op)(x.rate, y), x.compounding, x.daycount)
        end
    end
    @eval begin
        function ($op)(x::InterestRate, y::InterestRate)
            InterestRate(($op)(x.rate, equivalent(x, y).rate), x.compounding,
                x.daycount)
        end
    end
end
(+)(x::Real, y::InterestRate) = y + x
(*)(x::Real, y::InterestRate) = y * x
(-)(x::Real, y::InterestRate) = -1(y - x)
(/)(x::Real, y::InterestRate) = InterestRate(x / y.rate, y.compounding, y.daycount)

function (*)(x::DiscountFactor, y::DiscountFactor)
    if x.enddate == y.enddate || y.startdate == x.enddate
        return DiscountFactor(x.discountfactor * y.discountfactor,
            min(x.startdate, y.startdate), max(x.enddate, y.enddate))
    else
        error("The discount factors must represent two cotinguous spans of time.")
    end
end
function (/)(x::DiscountFactor, y::DiscountFactor)
    if x.startdate == y.startdate
        return DiscountFactor(x.discountfactor / y.discountfactor,
            min(x.enddate, y.enddate), max(x.enddate, y.enddate))
    else
        error("The discount factors must start at the same instant.")
    end
end

# comparison operations
for op in (:(==), :!=, :<, :<=, :>, :>=)
    @eval begin
        function ($op)(x::InterestRate, y::InterestRate)
            return ($op)(x.rate, equivalent(x, y).rate)
        end
        (($op)(x::DiscountFactor, y::DiscountFactor) =
            ($op)(x.discountfactor, y.discountfactor))
    end
end
