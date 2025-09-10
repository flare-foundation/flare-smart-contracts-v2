import tseslint from "typescript-eslint";
import { includeIgnoreFile } from "@eslint/compat";
import path from "node:path";
import { defineConfig } from 'eslint/config';


export default defineConfig([
    tseslint.configs.recommended,
    // linting with type information
    tseslint.configs.recommendedTypeChecked,
    // ignore everything in .gitignore
    includeIgnoreFile(path.resolve(".gitignore"), "Files from .gitignore"),
    {
        ignores: [
            'eslint.config.mjs',
            'scripts/**/*',
            '.solcover.js',
        ],
    },
    {
        languageOptions: {
            parserOptions: {
                projectService: true,
                tsconfigRootDir: import.meta.dirname,
            },
        },
        // import plugins for rules
        // plugins: { import: importPlugin },
        rules: {
            // Disables the rule that prefers the namespace keyword over the module keyword for declaring TypeScript namespaces.
            '@typescript-eslint/prefer-namespace-keyword': 'off',
            // Disables the rule that disallows the use of custom TypeScript namespaces.
            '@typescript-eslint/no-namespace': 'off',
            // Allow explicit type declarations for variables or parameters initialized to a number, string, or boolean.
            '@typescript-eslint/no-inferrable-types': 'off',
            // Warns about unused variables, but ignores variables that start with an underscore (^_) and arguments that match any pattern (.).
            '@typescript-eslint/no-unused-vars': [
                'warn',
                {
                    varsIgnorePattern: '^_',
                    argsIgnorePattern: '.',
                },
            ],
            // Don't prevent unstringified variables in templates - we don't care about perfect formatting in tests
            '@typescript-eslint/restrict-template-expressions': 'off',
            // Require for-in loops to include an if statement that checks hasOwnProperty.
            'guard-for-in': 'error',
            // Errors when a case in a switch statement falls through to the next case without a break statement or other termination.
            'no-fallthrough': 'error',
            // Require the use of === and !== instead of == and != for equality checks.
            'eqeqeq': ['warn', 'always', { null: 'ignore' }],
            // Disable async-without-await error
            '@typescript-eslint/require-await': 'off',
            // Change `any` related errors into warnings
            '@typescript-eslint/no-explicit-any': 'warn',
            '@typescript-eslint/no-unsafe-argument': 'warn',
            '@typescript-eslint/no-unsafe-assignment': 'warn',
            '@typescript-eslint/no-unsafe-call': 'warn',
            '@typescript-eslint/no-unsafe-declaration-merging': 'warn',
            '@typescript-eslint/no-unsafe-enum-comparison': 'warn',
            '@typescript-eslint/no-unsafe-function-type': 'warn',
            '@typescript-eslint/no-unsafe-member-access': 'warn',
            '@typescript-eslint/no-unsafe-return': 'warn',
            // Allow empty interfaces that extend type
            '@typescript-eslint/no-empty-object-type': [
                'error',
                {
                    allowInterfaces: 'with-single-extends'
                }
            ],
        },
    },
    // Override rules for specific files
    {
        files: ['test/**/*.ts'],
        rules: {
            // Disables the rule that disallows constant expressions in conditions (e.g., if (true)).
            'no-constant-condition': 'off',
            // Disables the rule that disallows non-null assertions using the ! postfix operator.
            '@typescript-eslint/no-non-null-assertion': 'off',
            // Disables the rule that disallows unused variables.
            '@typescript-eslint/no-unused-vars': 'off',
            // Disables the rule that disallows unused expressions.
            '@typescript-eslint/no-unused-expressions': 'off',
        },
    },
]);
