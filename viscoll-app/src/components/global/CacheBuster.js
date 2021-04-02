import React from 'react'
import packageJson from '../../../package.json'

global.appVersion = packageJson.version;

// version from response is the first param
// local version is the second param
const semverGreaterThan = (versionA, versionB) => {
    const versionsA = versionA.split(/\./g);
    const versionsB = versionB.split(/\./g);

    while (versionsA.length || versionsB.length) {
        const a = Number(versionsA.shift());
        const b = Number(versionsB.shift());

        if (a === b) continue;
        return a > b || isNaN(b);
    }
    return false;
};

class CacheBuster extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            loading: true,
            isLatestVersion: false,
            refreshCacheAndReload: () => {
                console.log('Clearing cache and hard reloading...')
                if (caches) {
                    caches.keys().then(function (names) {
                        for (let name of names) caches.delete(name)
                    })
                }
                // delete cache and reload
                window.location.reload(true);
            }
        }
    }

    componentDidMount() {
        fetch('/meta.json')
            .then((response) => response.json())
            .then((meta) => {
                const latestVersion = meta.version; // from latest build
                const currentVersion = global.appVersion; //cached browser version

                const shouldForceRefresh = semverGreaterThan(latestVersion, currentVersion);
                if (shouldForceRefresh) {
                    console.log(`We have a new version - ${latestVersion}. Should force refresh`)
                    this.setState({ loading: false, isLatestVersion: false })
                } else {
                    console.log(`You already have the latest version - ${latestVersion}. No cache refresh needed.`)
                    this.setState({ loading: false, isLatestVersion: true })
                }
            })
    }

    render() {
        const { loading, isLatestVersion, refreshCacheAndReload } = this.state;
        return this.props.children({ loading, isLatestVersion, refreshCacheAndReload });
    }
}

export default CacheBuster;