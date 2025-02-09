// DESCRIPTION: Verilator: Verilog example module
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2017 by Wilson Snyder.
// SPDX-License-Identifier: CC0-1.0
//======================================================================

// For std::unique_ptr
#include <memory>
#include <iostream>

// Include common routines
#include <verilated.h>

// Include model header, generated from Verilating "tb_harness.v"
#include "Vtb_harness.h"

// Legacy function required only so linking works on Cygwin and MSVC++
double sc_time_stamp() { return 0; }

#include <SDL2/SDL.h>


#define SCREEN_WIDTH 1024
#define SCREEN_HEIGHT 768


void set_pixel(Uint32 *buffer, int pos, SDL_Color color)
{
    buffer[pos] = *(Uint32 *)&color;
}

Uint32 *hdmi_screen;
int hdmi_p = 0;
bool pixclk_1d = false;

void display_loop()
{
    // Open the SDL Window
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
        return;

    SDL_Window *window = SDL_CreateWindow("SDL2 Window",
                                          SDL_WINDOWPOS_CENTERED,
                                          SDL_WINDOWPOS_CENTERED,
                                          SCREEN_WIDTH, SCREEN_HEIGHT,
                                          0);

    if (!window)
        return;

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    if (renderer == nullptr)
        return;

    SDL_Event e;
    bool running = true;

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
    if (texture == nullptr)
    {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return;
    }

    while (running)
    {
        while (SDL_PollEvent(&e) > 0)
        {
            switch (e.type)
            {
            case SDL_QUIT:
                running = false;
                break;
            }
        }

        SDL_UpdateTexture(texture, nullptr, hdmi_screen, SCREEN_WIDTH * sizeof(Uint32));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
    }

    delete hdmi_screen;
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

void display_dummy() {

}

void init_screen() {
    hdmi_screen = new Uint32[SCREEN_WIDTH * SCREEN_HEIGHT];
}


int main(int argc, char** argv) {
    // This is a more complicated example, please also see the simpler examples/make_hello_c.

    // Prevent unused variable warnings
    if (false && argc && argv) {}

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");

    // Construct a VerilatedContext to hold simulation time, etc.
    // Multiple modules (made later below with Vtop) may share the same
    // context to share time, or modules may have different contexts if
    // they should be independent from each other.

    // Using unique_ptr is similar to
    // "VerilatedContext* contextp = new VerilatedContext" then deleting at end.
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    // Do not instead make Vtop as a file-scope static variable, as the
    // "C++ static initialization order fiasco" may cause a crash


    // Set debug level, 0 is off, 9 is highest presently used
    // May be overridden by commandArgs argument parsing
    contextp->debug(0);

    // Randomization reset policy
    // May be overridden by commandArgs argument parsing
    contextp->randReset(2);

    // Verilator must compute traced signals
    contextp->traceEverOn(true);

    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    // This needs to be called before you create any model
    contextp->commandArgs(argc, argv);

    const char* disp_enable = contextp->commandArgsPlusMatch("disp");
    bool disp_enable_f = false;
    if (disp_enable && (strcmp(disp_enable, "+disp") == 0)) {
        disp_enable_f = true;
    }

    if (disp_enable_f) {
        init_screen();
    }

    std::thread disp_thread(disp_enable_f ? display_loop : display_dummy);

    // Construct the Verilated model, from Vtop.h generated from Verilating "top.v".
    // Using unique_ptr is similar to "Vtop* top = new Vtop" then deleting at end.
    // "TOP" will be the hierarchical name of the module.
    const std::unique_ptr<Vtb_harness> top{new Vtb_harness{contextp.get(), "TOP"}};

    // Set Vtop's input signals
    top->clk = 0;
    top->rst = 1;

    // Simulate until $finish
    while (!contextp->gotFinish()) {
        // Historical note, before Verilator 4.200 Verilated::gotFinish()
        // was used above in place of contextp->gotFinish().
        // Most of the contextp-> calls can use Verilated:: calls instead;
        // the Verilated:: versions just assume there's a single context
        // being used (per thread).  It's faster and clearer to use the
        // newer contextp-> versions.

        contextp->timeInc(1);  // 1 timeprecision period passes...
        // Historical note, before Verilator 4.200 a sc_time_stamp()
        // function was required instead of using timeInc.  Once timeInc()
        // is called (with non-zero), the Verilated libraries assume the
        // new API, and sc_time_stamp() will no longer work.

        // Toggle a fast (time/2 period) clock
        top->clk = !top->clk;

        if (!top->clk) {
            if (contextp->time() < 10) {
                top->rst = 1;  // Assert reset
            } else {
                top->rst = 0;  // Deassert reset
            }
        }

        // Evaluate model
        // (If you have multiple models being simulated in the same
        // timestep then instead of eval(), call eval_step() on each, then
        // eval_end_step() on each. See the manual.)
        top->eval();

        // Read outputs
//        VL_PRINTF("[%" PRId64 "] clk=%x rstl=%x iquad=%" PRIx64 " -> oquad=%" PRIx64
//                  " owide=%x_%08x_%08x\n",
//                  contextp->time(), top->clk, top->reset_l, top->in_quad, top->out_quad,
//                  top->out_wide[2], top->out_wide[1], top->out_wide[0]);

        if (disp_enable_f) {
            // rising edge, not hsync & vsync (active low), display is enabled
            if (top->clk && !pixclk_1d && top->hs && top->de && top->vs)
            {
                SDL_Color color;
                color.b = top->red << 4;
                color.g = top->green << 4;
                color.r = top->blue << 4;
                color.a = 0xFF;
                set_pixel(hdmi_screen, hdmi_p, color);
                hdmi_p = (hdmi_p + 1) % (SCREEN_WIDTH * SCREEN_HEIGHT);
            }
            pixclk_1d = top->clk;
        }
    }

    disp_thread.join();

    // Final model cleanup
    top->final();

    // Return good completion status
    // Don't use exit() or destructor won't get called
    return 0;
}