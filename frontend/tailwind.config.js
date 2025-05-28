/** @type {import('tailwindcss').Config} */
export default {
    theme: {
        extend: {
            fontFamily: {
                sans: [
                    '"__fontSurtNormal_693aa0"',
                    '"__fontSurtNormal_Fallback_693aa0"',
                    'system-ui',
                    '-apple-system',
                    'BlinkMacSystemFont',
                    '"Segoe UI"',
                    'Roboto',
                    'Oxygen',
                    'Ubuntu',
                    'Cantarell',
                    '"Open Sans"',
                    '"Helvetica Neue"',
                    'sans-serif',
                ],
            },
            colors: {
                black: 'rgb(44 42 42)',
                salmon: 'rgb(255 136 109)',
                cream: 'rgb(255 253 237)',
                white: 'rgb(255 255 255)',
                green: 'rgb(11 170 27)',
                'green-dark': 'rgb(8 97 17)',
                blue: 'rgb(112 145 223)',
                'blue-light': 'rgb(202 224 227)',
                'gray-1': 'rgb(246 246 246)',
                'gray-2': 'rgb(236 236 236)',
                'gray-3': 'rgb(182 182 182)',
                'gray-4': 'rgb(92 92 92)',
                'gray-5': 'rgb(232 232 232)',
                error: 'rgb(215 65 32)',
                gray: 'rgb(86 84 81)',
                'gray-disabled': 'rgb(217 217 217)',
            },
        },
    },
    plugins: [],
}; 