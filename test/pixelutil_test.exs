defmodule Inky.PixelUtilTest do
  @moduledoc false

  use ExUnit.Case

  import Inky.PixelUtil, only: [pixels_to_bits: 5, pixels_to_4bpp: 4]

  doctest Inky.PixelUtil

  setup_all do
    %{:sq3 => for(i <- 0..2, j <- 0..2, do: {i, j})}
  end

  defp seed_pixels(points, p2c) do
    for {i, j} <- points, do: {{i, j}, p2c.(i, j)}, into: %{}
  end

  defp to_bit_list(bitstring) do
    for <<b::1 <- bitstring>>, do: b, into: []
  end

  describe "pixels_to_4bpp" do
    @color_map %{black: 0, white: 1, green: 2, blue: 3, red: 4, yellow: 5, orange: 6, miss: 1}

    test "packs two pixels per byte, high nibble first" do
      pixels = %{{0, 0} => :black, {1, 0} => :white}
      result = pixels_to_4bpp(pixels, 2, 1, @color_map)
      assert result == <<0::4, 1::4>>
    end

    test "uses miss value for unknown pixels" do
      result = pixels_to_4bpp(%{}, 4, 1, @color_map)
      assert byte_size(result) == 2
      assert result == <<1::4, 1::4, 1::4, 1::4>>
    end

    test "produces correct byte count for 800x480" do
      result = pixels_to_4bpp(%{}, 800, 480, @color_map)
      assert byte_size(result) == 800 * 480 / 2
    end

    test "maps all 7 colors correctly in a single row" do
      pixels =
        %{
          {0, 0} => :black, {1, 0} => :white,
          {2, 0} => :green, {3, 0} => :blue,
          {4, 0} => :red,   {5, 0} => :yellow,
          {6, 0} => :orange, {7, 0} => :white
        }

      result = pixels_to_4bpp(pixels, 8, 1, @color_map)
      assert result == <<0::4, 1::4, 2::4, 3::4, 4::4, 5::4, 6::4, 1::4>>
    end
  end

  describe "the new pixel conversion API" do
    test "black, 3x3 pixels", ctx do
      pixels = seed_pixels(ctx.sq3, fn _, _ -> :black end)
      bitstring = pixels_to_bits(pixels, 3, 3, 0, %{black: 0, miss: 1})
      assert to_bit_list(bitstring) == [0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    test "specific color, red", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :white
          2, _ -> :red
        end)

      color_map = %{red: 1, yellow: 1, accent: 1, miss: 0}
      bits = pixels |> pixels_to_bits(3, 3, 0, color_map)
      assert to_bit_list(bits) == [0, 0, 1, 0, 0, 1, 0, 0, 1]
    end

    test "generic color, accent", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :accent
          2, _ -> :white
        end)

      color_map = %{red: 1, yellow: 1, accent: 1, miss: 0}
      bits = pixels |> pixels_to_bits(3, 3, 0, color_map)
      assert to_bit_list(bits) == [0, 1, 0, 0, 1, 0, 0, 1, 0]
    end
  end
end
