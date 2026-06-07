unit class GrammarDB::Service;
use GrammarDB::Engine;
use GrammarDB::Model;

has GrammarDB::Engine $.engine is required;
has Int $.threshold = 10;
has $.commit-interval = 1; 

has Int $!unsaved-changes = 0;
has Lock $!lock .= new;
has $!janitor-thread;
has atomicint $!is-running = 1;

submethod TWEAK() {
    $!janitor-thread = start {
        while $!is-running {
            sleep $!commit-interval;
            self.commit;
        }
    }
}

method query(Str $attr, Str $val, :$class = Any) {
    $!lock.protect: { return $!engine.find-by($class, $attr, $val) }
}

method insert(GrammarDB::Model $obj) {
    $!lock.protect: {
        $!engine.insert($obj);
        $!unsaved-changes++;
        if $!unsaved-changes >= $!threshold {
            $!engine.commit;
            $!unsaved-changes = 0;
        }
    }
}

method notify-change() {
    $!lock.protect: {
        $!unsaved-changes++;
        if $!unsaved-changes >= $!threshold {
            $!engine.commit;
            $!unsaved-changes = 0;
        }
    }
}

# --- THE FIX ---
method commit() {
    $!lock.protect: {
        # We REMOVE the counter check. If commit() is called, 
        # we tell the engine to write. Period.
        $!engine.commit;
        $!unsaved-changes = 0;
    }
    # Return a kept promise to satisfy the API
    return Promise.kept(True);
}

method shutdown() {
    $!is-running ⚛= 0;
    try await $!janitor-thread;
    $!lock.protect: { $!engine.commit }
}