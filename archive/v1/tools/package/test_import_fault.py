"""The sole allowed import retry must distinguish completed teardown from errors."""
import unittest
from build_windows_beta import completed_import_fault


class ImportFault(unittest.TestCase):
    done = "[ DONE ] reimport\n[ DONE ] loading_editor_layout\n"
    fault = RuntimeError("Command failed (3221225477); see import.log")

    def test_completed_plain_and_real_colored_progress(self):
        colored = "\x1b[92m[ DONE ]\x1b[39m \x1b[1mreimport\x1b[22m\n\x1b[92m[ DONE ]\x1b[39m \x1b[1mloading_editor_layout\x1b[22m\n"
        self.assertTrue(completed_import_fault(self.fault, self.done))
        self.assertTrue(completed_import_fault(self.fault, colored))

    def test_incomplete_import_or_editor_setup_stays_fatal(self):
        self.assertFalse(completed_import_fault(self.fault, "[ 98% ] reimport | Finalizing\n"))
        self.assertFalse(completed_import_fault(self.fault, "[ DONE ] reimport\n"))

    def test_script_and_resource_errors_stay_fatal(self):
        self.assertFalse(completed_import_fault(self.fault, "SCRIPT ERROR: bad script\n" + self.done))
        self.assertFalse(completed_import_fault(self.fault, "\x1b[31mERROR:\x1b[0m bad resource\n" + self.done))

    def test_other_exit_codes_stay_fatal(self):
        self.assertFalse(completed_import_fault(RuntimeError("Command failed (1)"), self.done))
        self.assertFalse(completed_import_fault(RuntimeError("Command failed (3221226505)"), self.done))


if __name__ == "__main__":
    unittest.main()
