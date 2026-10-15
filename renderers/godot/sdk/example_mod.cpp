#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/omni_light3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <cmath>

using namespace godot;

class MgsExampleMod : public Node3D {
    GDCLASS(MgsExampleMod, Node3D)

    Object *context = nullptr;
    OmniLight3D *light = nullptr;
    Vector3 origin;
    double elapsed = 0.0;

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("mgs_mod_initialize", "context"), &MgsExampleMod::mgs_mod_initialize);
        ClassDB::bind_method(D_METHOD("mgs_mod_shutdown"), &MgsExampleMod::mgs_mod_shutdown);
        ClassDB::bind_method(D_METHOD("stage_changed", "stage"), &MgsExampleMod::stage_changed);
    }

public:
    int mgs_mod_initialize(Object *api) {
        if (!api || int(api->call("get_api_version")) != 1) {
            return ERR_UNAVAILABLE;
        }
        const Error error = api->connect("stage_changed", Callable(this, "stage_changed"));
        if (error != OK) {
            return error;
        }
        context = api;
        light = memnew(OmniLight3D);
        light->set_name("MovingLight");
        light->set_shadow(true);
        light->set_param(Light3D::PARAM_RANGE, 12.0);
        light->set_param(Light3D::PARAM_ENERGY, 3.5);
        light->set_color(Color(1.0, 0.75, 0.45));
        add_child(light);
        stage_changed(context->call("get_stage"));
        set_process(true);
        return OK;
    }

    void stage_changed(const String &stage) {
        const bool supported = stage == "s00a" || stage == "s01a";
        set_visible(supported);
        origin = stage == "s00a" ? Vector3(-6, 3, 5) : Vector3(-4, 4, -20);
        elapsed = 0.0;
        if (light) {
            light->set_position(origin);
        }
    }

    void _process(double delta) override {
        elapsed += delta;
        if (light && is_visible()) {
            light->set_position(origin + Vector3(std::sin(elapsed) * 2.0, 0, 0));
        }
    }

    void mgs_mod_shutdown() {
        set_process(false);
        if (context) {
            context->disconnect("stage_changed", Callable(this, "stage_changed"));
            context = nullptr;
        }
    }
};

static void initialize_mod(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<MgsExampleMod>();
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT mgs_visual_mod_init(GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize_mod);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
