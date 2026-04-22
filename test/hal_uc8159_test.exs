defmodule Inky.HAL.UC8159Test do
  @moduledoc false

  use ExUnit.Case

  alias Inky.Display
  alias Inky.HAL.UC8159
  alias Inky.TestIO

  import Inky.TestUtil, only: [gather_messages: 0]
  import Inky.TestVerifier, only: [load_spec: 2, check: 2]

  defp all_white(width, height) do
    for x <- 0..(width - 1), y <- 0..(height - 1), do: {{x, y}, :white}, into: %{}
  end

  describe "init" do
    test "dispatches to io_mod with spi_speed_hz set to 3MHz" do
      display = Display.spec_for(:impression_73)

      UC8159.init(%{
        display: display,
        io_args: [],
        io_mod: TestIO
      })

      assert_received {:init, init_args}
      assert init_args[:spi_speed_hz] == 3_000_000
      refute_receive _
    end
  end

  describe "handle_update" do
    test "sends correct command sequence when device is immediately ready" do
      display = Display.spec_for(:impression_73)
      pixels = all_white(800, 480)

      state = UC8159.init(%{
        display: display,
        io_args: [read_busy: 1],
        io_mod: TestIO
      })

      assert_received {:init, _}

      :ok = UC8159.handle_update(pixels, :black, :await, state)

      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/uc8159_success.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 21}
    end

    test "returns device_busy error when device is busy and policy is :once" do
      display = Display.spec_for(:impression_73)
      pixels = all_white(800, 480)

      state = UC8159.init(%{
        display: display,
        io_args: [read_busy: 0],
        io_mod: TestIO
      })

      assert_received {:init, _}

      result = UC8159.handle_update(pixels, :black, :once, state)
      assert result == {:error, :device_busy}
    end

    test "waits through busy cycles with :await policy" do
      display = Display.spec_for(:impression_73)
      pixels = all_white(800, 480)

      # busy=0 (busy) twice, then busy=1 (ready) for pre_update,
      # then busy=1 for all subsequent awaits
      state = UC8159.init(%{
        display: display,
        io_args: [read_busy: [0, 0, 1, 1, 1, 1]],
        io_mod: TestIO
      })

      assert_received {:init, _}

      :ok = UC8159.handle_update(pixels, :black, :await, state)
      assert TestIO.assert_expectations() == :ok
    end
  end
end
